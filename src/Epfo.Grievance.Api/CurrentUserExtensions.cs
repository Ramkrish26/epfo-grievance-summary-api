using System.Security.Claims;
using Epfo.Grievance.Application;

namespace Epfo.Grievance.Api;

public static class CurrentUserExtensions
{
    public static AccessScope GetAccessScope(this ClaimsPrincipal user)
    {
        var userId = long.TryParse(user.FindFirstValue(ClaimTypes.NameIdentifier), out var parsedUserId) ? parsedUserId : throw new UnauthorizedAccessException();
        var officeId = int.TryParse(user.FindFirstValue("office_id"), out var parsedOfficeId) ? parsedOfficeId : throw new UnauthorizedAccessException("The token does not contain an office assignment. Sign in again.");
        return new AccessScope(userId, officeId, user.FindAll(ClaimTypes.Role).Select(x => x.Value).ToArray());
    }
}
