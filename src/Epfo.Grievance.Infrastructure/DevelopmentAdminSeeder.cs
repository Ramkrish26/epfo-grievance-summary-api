using Epfo.Grievance.Domain;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace Epfo.Grievance.Infrastructure;

public sealed class DevelopmentAdminSeeder(EpfoDbContext db, IConfiguration configuration, IPasswordHasher<User> passwords)
{
    public async Task SeedAsync(CancellationToken cancellationToken)
    {
        var username = configuration["BootstrapAdmin:Username"];
        var password = configuration["BootstrapAdmin:Password"];
        if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password) || await db.Users.AnyAsync(cancellationToken)) return;

        var office = await db.Offices.OrderBy(x => x.OfficeId).FirstOrDefaultAsync(cancellationToken) ?? throw new InvalidOperationException("Run the database schema script before starting the API.");
        var role = await db.Roles.SingleOrDefaultAsync(x => x.RoleCode == "SUPERADMIN", cancellationToken) ?? throw new InvalidOperationException("Run the database schema script before starting the API.");
        var user = new User { OfficeId = office.OfficeId, Username = username, DisplayName = "Development Administrator", PasswordHash = "", IsEnabled = true };
        user.PasswordHash = passwords.HashPassword(user, password);
        db.Users.Add(user);
        await db.SaveChangesAsync(cancellationToken);
        db.UserRoles.Add(new UserRole { UserId = user.UserId, RoleId = role.RoleId });
        await db.SaveChangesAsync(cancellationToken);
    }
}
