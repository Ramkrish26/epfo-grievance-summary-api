using Epfo.Grievance.Api;
using Amazon.Lambda.AspNetCoreServer;
using Amazon.Lambda.AspNetCoreServer.Hosting;
using Amazon.SecretsManager;
using Amazon.SecretsManager.Model;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);
var databaseSecretArn = builder.Configuration["Database:SecretArn"];
if (!string.IsNullOrWhiteSpace(databaseSecretArn))
{
    using var secrets = new AmazonSecretsManagerClient();
    var secret = await secrets.GetSecretValueAsync(new GetSecretValueRequest { SecretId = databaseSecretArn });
    using var document = JsonDocument.Parse(secret.SecretString);
    var username = document.RootElement.GetProperty("username").GetString();
    var password = document.RootElement.GetProperty("password").GetString();
    var endpoint = builder.Configuration["Database:Endpoint"];
    var port = builder.Configuration["Database:Port"] ?? "1433";
    var databaseName = builder.Configuration["Database:Name"] ?? "EpfoGrievance";
    if (string.IsNullOrWhiteSpace(endpoint) || string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password)) throw new InvalidOperationException("Database endpoint and RDS secret credentials are required for Lambda hosting.");
    builder.Configuration.AddInMemoryCollection(new Dictionary<string, string?> { ["ConnectionStrings:EpfoGrievance"] = $"Server={endpoint},{port};Database={databaseName};User Id={username};Password={password};Encrypt=True;TrustServerCertificate=False" });
}
builder.Services.AddControllers();
builder.Services.AddOpenApi();
builder.Services.AddAWSLambdaHosting(LambdaEventSource.RestApi);
builder.Services.AddAuthorization(options => options.DefaultPolicy = new Microsoft.AspNetCore.Authorization.AuthorizationPolicyBuilder().RequireAuthenticatedUser().RequireClaim("office_id").Build());
builder.Services.AddEpfoServices(builder.Configuration);
builder.Services.AddCors(options => options.AddPolicy("ui", policy => policy.WithOrigins(builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? ["http://localhost:5173"]).AllowAnyHeader().AllowAnyMethod()));
var app = builder.Build();
app.UseHttpsRedirection(); app.UseCors("ui"); app.UseAuthentication(); app.UseAuthorization(); app.MapGet("/health", () => Results.Ok(new { status = "healthy" })).AllowAnonymous(); app.MapOpenApi(); app.MapControllers(); app.Run();
