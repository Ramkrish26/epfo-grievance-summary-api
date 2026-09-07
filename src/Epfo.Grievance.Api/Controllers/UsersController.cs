using Epfo.Grievance.Application;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Epfo.Grievance.Api.Controllers;

[Authorize(Roles = "SUPERADMIN,ADMIN")]
[ApiController]
[Route("api/users")]
public sealed class UsersController(IUserService users) : ControllerBase
{
    [HttpGet("reference-data")]
    public Task<UserReferenceData> GetReferenceData(CancellationToken ct) => users.GetReferenceDataAsync(User.GetAccessScope(), ct);

    [HttpGet]
    public Task<IReadOnlyCollection<UserResponse>> List(CancellationToken ct) => users.ListAsync(User.GetAccessScope(), ct);

    [HttpPost]
    public async Task<ActionResult<UserResponse>> Create(CreateUserRequest request, CancellationToken ct)
    {
        try { var user = await users.CreateAsync(request, User.GetAccessScope(), ct); return Created("/api/users/" + user.UserId, user); }
        catch (ArgumentException error) { return BadRequest(new { message = error.Message }); }
        catch (InvalidOperationException error) { return Conflict(new { message = error.Message }); }
        catch (UnauthorizedAccessException) { return Forbid(); }
    }

    [HttpPatch("{userId:long}/role")]
    public async Task<ActionResult<UserResponse>> UpdateRole(long userId, UpdateUserRoleRequest request, CancellationToken ct)
    { try { return await users.UpdateRoleAsync(userId, request, User.GetAccessScope(), ct) is { } user ? Ok(user) : NotFound(); } catch (ArgumentException error) { return BadRequest(new { message = error.Message }); } catch (UnauthorizedAccessException) { return Forbid(); } }

    [HttpPatch("{userId:long}/status")]
    public async Task<ActionResult<UserResponse>> UpdateStatus(long userId, UpdateUserStatusRequest request, CancellationToken ct)
    { try { return await users.UpdateStatusAsync(userId, request, User.GetAccessScope(), ct) is { } user ? Ok(user) : NotFound(); } catch (UnauthorizedAccessException) { return Forbid(); } }
}
