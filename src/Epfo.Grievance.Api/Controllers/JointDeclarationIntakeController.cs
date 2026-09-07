using Epfo.Grievance.Application;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Epfo.Grievance.Api.Controllers;

[Authorize(Roles = "RECEIPT,ADMIN,SUPERADMIN")]
[ApiController]
[Route("api/jd-intake")]
public sealed class JointDeclarationIntakeController(IJointDeclarationService declarations) : ControllerBase
{
    [HttpPost]
    public async Task<ActionResult<JdCaseListItem>> Create(CreateCaseRequest request, CancellationToken ct)
    {
        try
        {
            var created = await declarations.CreateIntakeAsync(request, User.GetAccessScope(), ct);
            return Created("/api/jd-cases?stage=da-ack", created);
        }
        catch (ArgumentException error)
        {
            return BadRequest(new { message = error.Message });
        }
        catch (UnauthorizedAccessException)
        {
            return Forbid();
        }
    }
}
