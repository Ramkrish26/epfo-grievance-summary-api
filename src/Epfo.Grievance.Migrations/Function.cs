using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Amazon.Lambda.Core;
using Amazon.Lambda.Serialization.SystemTextJson;
using Amazon.SecretsManager;
using Amazon.SecretsManager.Model;
using Microsoft.Data.SqlClient;

[assembly: LambdaSerializer(typeof(DefaultLambdaJsonSerializer))]

namespace Epfo.Grievance.Migrations;

public sealed class Function
{
    private static readonly Regex GoBatchSeparator = new("^\\s*GO\\s*;?\\s*$", RegexOptions.Multiline | RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

    public async Task<MigrationResult> FunctionHandler(MigrationRequest? request, ILambdaContext context)
    {
        var settings = MigrationSettings.FromEnvironment();
        var secret = await ReadSecretAsync(settings.SecretArn);
        var masterConnectionString = BuildConnectionString(secret, settings, "master");

        await EnsureDatabaseAsync(masterConnectionString, settings.DatabaseName);

        await using var connection = new SqlConnection(BuildConnectionString(secret, settings, settings.DatabaseName));
        await connection.OpenAsync();
        await EnsureMigrationHistoryAsync(connection);
        await AcquireMigrationLockAsync(connection);

        try
        {
            var applied = new List<string>();
            var skipped = new List<string>();

            foreach (var script in ReadEmbeddedScripts())
            {
                var recordedHash = await GetRecordedHashAsync(connection, script.MigrationId);
                if (recordedHash is not null)
                {
                    if (!string.Equals(recordedHash, script.Hash, StringComparison.OrdinalIgnoreCase))
                    {
                        throw new InvalidOperationException($"Migration '{script.MigrationId}' was previously applied with a different script hash. Create a new migration file instead of modifying an existing one.");
                    }

                    skipped.Add(script.MigrationId);
                    continue;
                }

                context.Logger.LogInformation($"Applying database migration {script.MigrationId}.");
                await ExecuteScriptAsync(connection, script.Contents);
                await RecordMigrationAsync(connection, script, request?.RequestedBy ?? "github-actions");
                applied.Add(script.MigrationId);
            }

            return new MigrationResult(applied, skipped);
        }
        finally
        {
            await ReleaseMigrationLockAsync(connection);
        }
    }

    private static async Task<DatabaseSecret> ReadSecretAsync(string secretArn)
    {
        using var client = new AmazonSecretsManagerClient();
        var response = await client.GetSecretValueAsync(new GetSecretValueRequest { SecretId = secretArn });
        using var document = JsonDocument.Parse(response.SecretString);
        var root = document.RootElement;
        return new DatabaseSecret(
            root.GetProperty("username").GetString() ?? throw new InvalidOperationException("Database secret does not contain a username."),
            root.GetProperty("password").GetString() ?? throw new InvalidOperationException("Database secret does not contain a password."));
    }

    private static string BuildConnectionString(DatabaseSecret secret, MigrationSettings settings, string database)
        => new SqlConnectionStringBuilder
        {
            DataSource = $"{settings.Endpoint},{settings.Port}",
            InitialCatalog = database,
            UserID = secret.Username,
            Password = secret.Password,
            Encrypt = true,
            TrustServerCertificate = false,
            ConnectTimeout = 30,
            ConnectRetryCount = 3,
            ConnectRetryInterval = 5
        }.ConnectionString;

    private static async Task EnsureDatabaseAsync(string connectionString, string databaseName)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandTimeout = 300;
        command.CommandText = "IF DB_ID(@databaseName) IS NULL EXEC(N'CREATE DATABASE ' + QUOTENAME(@databaseName));";
        command.Parameters.AddWithValue("@databaseName", databaseName);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task EnsureMigrationHistoryAsync(SqlConnection connection)
    {
        const string sql = """
            IF OBJECT_ID(N'dbo.__EpfoSchemaMigrations', N'U') IS NULL
            BEGIN
                CREATE TABLE dbo.__EpfoSchemaMigrations (
                    MigrationId NVARCHAR(260) NOT NULL CONSTRAINT PK_EpfoSchemaMigrations PRIMARY KEY,
                    ScriptHash CHAR(64) NOT NULL,
                    AppliedAtUtc DATETIME2 NOT NULL CONSTRAINT DF_EpfoSchemaMigrations_AppliedAtUtc DEFAULT SYSUTCDATETIME(),
                    AppliedBy NVARCHAR(200) NOT NULL
                );
            END;
            """;
        await ExecuteCommandAsync(connection, sql);
    }

    private static async Task AcquireMigrationLockAsync(SqlConnection connection)
    {
        const string sql = """
            DECLARE @result INT;
            EXEC @result = sp_getapplock
                @Resource = N'EPFO:SchemaMigration',
                @LockMode = N'Exclusive',
                @LockOwner = N'Session',
                @LockTimeout = 60000;
            SELECT @result;
            """;
        await using var command = connection.CreateCommand();
        command.CommandTimeout = 90;
        command.CommandText = sql;
        var result = Convert.ToInt32(await command.ExecuteScalarAsync());
        if (result < 0) throw new InvalidOperationException($"Could not acquire the database migration lock. SQL Server returned {result}.");
    }

    private static Task ReleaseMigrationLockAsync(SqlConnection connection)
        => ExecuteCommandAsync(connection, "EXEC sp_releaseapplock @Resource = N'EPFO:SchemaMigration', @LockOwner = N'Session';");

    private static async Task<string?> GetRecordedHashAsync(SqlConnection connection, string migrationId)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT ScriptHash FROM dbo.__EpfoSchemaMigrations WHERE MigrationId = @migrationId;";
        command.Parameters.AddWithValue("@migrationId", migrationId);
        return await command.ExecuteScalarAsync() as string;
    }

    private static async Task ExecuteScriptAsync(SqlConnection connection, string script)
    {
        foreach (var batch in GoBatchSeparator.Split(script).Where(batch => !string.IsNullOrWhiteSpace(batch)))
        {
            await ExecuteCommandAsync(connection, batch);
        }
    }

    private static async Task ExecuteCommandAsync(SqlConnection connection, string sql)
    {
        await using var command = connection.CreateCommand();
        command.CommandTimeout = 300;
        command.CommandText = sql;
        await command.ExecuteNonQueryAsync();
    }

    private static async Task RecordMigrationAsync(SqlConnection connection, MigrationScript script, string appliedBy)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = "INSERT dbo.__EpfoSchemaMigrations (MigrationId, ScriptHash, AppliedBy) VALUES (@migrationId, @scriptHash, @appliedBy);";
        command.Parameters.AddWithValue("@migrationId", script.MigrationId);
        command.Parameters.AddWithValue("@scriptHash", script.Hash);
        command.Parameters.AddWithValue("@appliedBy", appliedBy);
        await command.ExecuteNonQueryAsync();
    }

    private static IEnumerable<MigrationScript> ReadEmbeddedScripts()
    {
        var assembly = Assembly.GetExecutingAssembly();
        return assembly.GetManifestResourceNames()
            .Where(name => name.StartsWith("Migrations/", StringComparison.Ordinal) && name.EndsWith(".sql", StringComparison.OrdinalIgnoreCase))
            .OrderBy(name => name, StringComparer.Ordinal)
            .Select(name =>
            {
                using var stream = assembly.GetManifestResourceStream(name) ?? throw new InvalidOperationException($"Embedded migration '{name}' could not be read.");
                using var reader = new StreamReader(stream, Encoding.UTF8, detectEncodingFromByteOrderMarks: true);
                var contents = reader.ReadToEnd();
                return new MigrationScript(name["Migrations/".Length..], contents, Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(contents))));
            })
            .ToArray();
    }

    private sealed record DatabaseSecret(string Username, string Password);
    private sealed record MigrationScript(string MigrationId, string Contents, string Hash);
}

public sealed record MigrationRequest(string? RequestedBy);
public sealed record MigrationResult(IReadOnlyCollection<string> Applied, IReadOnlyCollection<string> Skipped);

internal sealed record MigrationSettings(string Endpoint, int Port, string DatabaseName, string SecretArn)
{
    public static MigrationSettings FromEnvironment()
    {
        static string Required(string name) => Environment.GetEnvironmentVariable(name) ?? throw new InvalidOperationException($"Required environment variable '{name}' is missing.");
        return new MigrationSettings(Required("Database__Endpoint"), int.Parse(Required("Database__Port")), Required("Database__Name"), Required("Database__SecretArn"));
    }
}
