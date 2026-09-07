using Epfo.Grievance.Application;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Epfo.Grievance.Api.Controllers;

[ApiController]
[Route("api/auth")]
public sealed class AuthController(IAuthService auth) : ControllerBase
{
    [AllowAnonymous]
    [HttpGet("offices")]
    public Task<IReadOnlyCollection<OfficeOption>> Offices(CancellationToken ct) => auth.GetOfficesAsync(ct);

    [AllowAnonymous]
    [HttpPost("login")]
    public async Task<ActionResult<LoginResponse>> Login(LoginRequest request, CancellationToken ct) => (await auth.LoginAsync(request, ct)) is { } result ? Ok(result) : Unauthorized(new { message = "Invalid credentials or role." });

    [Authorize(Roles = "SUPERADMIN")]
    [HttpPost("switch-office")]
    public async Task<ActionResult<LoginResponse>> SwitchOffice(SwitchOfficeRequest request, CancellationToken ct)
    { try { return await auth.SwitchOfficeAsync(request, User.GetAccessScope(), ct) is { } result ? Ok(result) : BadRequest(new { message = "The selected office is unavailable." }); } catch (UnauthorizedAccessException) { return Forbid(); } }

    [AllowAnonymous]
    [HttpPost("signup")]
    public async Task<ActionResult<UserResponse>> SignUp(SignUpRequest request, CancellationToken ct)
    {
        try { var user = await auth.SignUpAsync(request, ct); return Created("/api/users/" + user.UserId, user); }
        catch (ArgumentException error) { return BadRequest(new { message = error.Message }); }
        catch (InvalidOperationException error) { return Conflict(new { message = error.Message }); }
    }

}
