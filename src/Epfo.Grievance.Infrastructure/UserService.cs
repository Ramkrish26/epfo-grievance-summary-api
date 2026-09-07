using Epfo.Grievance.Application;
using Epfo.Grievance.Domain;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Epfo.Grievance.Infrastructure;

public sealed class UserService(EpfoDbContext db, IPasswordHasher<User> passwords) : IUserService
{
    public async Task<UserResponse> CreateAsync(CreateUserRequest request, AccessScope scope, CancellationToken ct)
    {
        EnsureAdministrator(scope);
        var office = await FindOfficeAsync(request.OfficeCode, ct); var role = await FindRoleAsync(request.RoleCode, ct);
        if (office.OfficeId != scope.OfficeId) throw new UnauthorizedAccessException("Switch to the target office before creating a user there.");
        if (!scope.IsSuperAdmin && IsPrivilegedRole(role.RoleCode)) throw new UnauthorizedAccessException("Office administrators can create regular users only.");
        return await AddUserAsync(request.Username, request.Password, request.DisplayName, request.Email, office, role, true, ct);
    }

    public async Task<IReadOnlyCollection<UserResponse>> ListAsync(AccessScope scope, CancellationToken ct)
    {
        EnsureAdministrator(scope); var query = UserQuery().Where(x => x.OfficeId == scope.OfficeId); if (!scope.IsSuperAdmin) query = query.Where(x => !x.UserRoles.Any(r => r.Role.RoleCode == "SUPERADMIN" || r.Role.RoleCode == "ADMIN"));
        return await query.OrderBy(x => x.DisplayName).Select(ToResponse()).ToListAsync(ct);
    }

    public async Task<UserResponse?> UpdateRoleAsync(long userId, UpdateUserRoleRequest request, AccessScope scope, CancellationToken ct)
    {
        EnsureAdministrator(scope); var user = await UserQuery().SingleOrDefaultAsync(x => x.UserId == userId, ct); if (user is null) return null;
        var role = await FindRoleAsync(request.RoleCode, ct); EnsureCanManage(scope, user, role.RoleCode);
        db.UserRoles.RemoveRange(user.UserRoles); user.UserRoles = [new UserRole { UserId = user.UserId, RoleId = role.RoleId, Role = role }]; await db.SaveChangesAsync(ct);
        return ToResponse().Compile().Invoke(user);
    }

    public async Task<UserResponse?> UpdateStatusAsync(long userId, UpdateUserStatusRequest request, AccessScope scope, CancellationToken ct)
    {
        EnsureAdministrator(scope); var user = await UserQuery().SingleOrDefaultAsync(x => x.UserId == userId, ct); if (user is null) return null;
        EnsureCanManage(scope, user, null); user.IsEnabled = request.IsEnabled; await db.SaveChangesAsync(ct); return ToResponse().Compile().Invoke(user);
    }

    public async Task<UserReferenceData> GetReferenceDataAsync(AccessScope scope, CancellationToken ct)
    {
        EnsureAdministrator(scope); var roles = db.Roles.Where(x => x.IsActive); var offices = db.Offices.Where(x => x.IsActive && x.OfficeId == scope.OfficeId);
        if (!scope.IsSuperAdmin) roles = roles.Where(x => x.RoleCode != "SUPERADMIN" && x.RoleCode != "ADMIN");
        return new(await roles.OrderBy(x => x.DisplayName).Select(x => new RoleOption(x.RoleCode, x.DisplayName)).ToListAsync(ct), await offices.OrderBy(x => x.OfficeName).Select(x => new OfficeOption(x.OfficeCode, x.OfficeName)).ToListAsync(ct));
    }

    private IQueryable<User> UserQuery() => db.Users.Include(x => x.Office).Include(x => x.UserRoles).ThenInclude(x => x.Role);
    private async Task<Office> FindOfficeAsync(string officeCode, CancellationToken ct) => await db.Offices.SingleOrDefaultAsync(x => x.OfficeCode == officeCode && x.IsActive, ct) ?? throw new ArgumentException("Unknown or inactive office.");
    private async Task<Role> FindRoleAsync(string roleCode, CancellationToken ct) => await db.Roles.SingleOrDefaultAsync(x => x.RoleCode == roleCode && x.IsActive, ct) ?? throw new ArgumentException("Unknown or inactive role.");
    private static bool IsPrivilegedRole(string roleCode) => roleCode.Equals("SUPERADMIN", StringComparison.OrdinalIgnoreCase) || roleCode.Equals("ADMIN", StringComparison.OrdinalIgnoreCase);
    private static void EnsureAdministrator(AccessScope scope) { if (!scope.IsSuperAdmin && !scope.IsAdmin) throw new UnauthorizedAccessException("Administrator access is required."); }
    private static void EnsureCanManage(AccessScope scope, User user, string? requestedRole) { if (user.OfficeId != scope.OfficeId) throw new UnauthorizedAccessException("Switch to the target office before managing this user."); if (scope.IsSuperAdmin) return; if (user.UserRoles.Any(x => IsPrivilegedRole(x.Role.RoleCode)) || (requestedRole is not null && IsPrivilegedRole(requestedRole))) throw new UnauthorizedAccessException("Office administrators can manage regular users in their own office only."); }
    private async Task<UserResponse> AddUserAsync(string username, string password, string displayName, string? email, Office office, Role role, bool enabled, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(displayName) || string.IsNullOrWhiteSpace(password) || password.Length < 12) throw new ArgumentException("Username and display name are required; passwords must be at least 12 characters.");
        if (await db.Users.AnyAsync(x => x.Username == username || (email != null && x.Email == email), ct)) throw new InvalidOperationException("A user with that username or email already exists.");
        var user = new User { OfficeId = office.OfficeId, Office = office, Username = username.Trim(), DisplayName = displayName.Trim(), Email = string.IsNullOrWhiteSpace(email) ? null : email.Trim(), PasswordHash = "", IsEnabled = enabled, UserRoles = [new UserRole { Role = role }] };
        user.PasswordHash = passwords.HashPassword(user, password); db.Users.Add(user); await db.SaveChangesAsync(ct); return ToResponse().Compile().Invoke(user);
    }
    private static System.Linq.Expressions.Expression<Func<User, UserResponse>> ToResponse() => x => new UserResponse(x.UserId, x.Username, x.DisplayName, x.Email, x.Office.OfficeCode, x.UserRoles.Select(r => r.Role.RoleCode).ToArray(), x.IsEnabled);
}
