using Epfo.Grievance.Application;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Epfo.Grievance.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/dashboard")]
public sealed class DashboardController(ICaseService cases) : ControllerBase
{
    [HttpGet("summary")]
    public Task<DashboardSummary> GetSummary(CancellationToken ct) => cases.GetDashboardSummaryAsync(User.GetAccessScope(), ct);
}
