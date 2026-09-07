using System.Text;
using Epfo.Grievance.Application;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Epfo.Grievance.Api.Controllers;

[Authorize(Roles = "JDCELL,JDCELLSS,ADMIN,SUPERADMIN")]
[ApiController]
[Route("api/jd-cases")]
public sealed class JointDeclarationsController(IJointDeclarationService declarations) : ControllerBase
{
    [HttpGet] public Task<IReadOnlyCollection<JdCaseListItem>> List([FromQuery] string stage = "all", CancellationToken ct = default) => declarations.ListAsync(stage, User.GetAccessScope(), ct);
    [Authorize(Roles = "JDCELL,SUPERADMIN")][HttpPost("{referenceNumber}/da-acknowledge")] public Task<ActionResult<JdCaseListItem>> AcknowledgeDa(string referenceNumber, CancellationToken ct) => Execute(() => declarations.AcknowledgeDaAsync(referenceNumber, User.GetAccessScope(), ct));
    [Authorize(Roles = "JDCELL,SUPERADMIN")][HttpPost("{referenceNumber}/da-decision")] public Task<ActionResult<JdCaseListItem>> DecideDa(string referenceNumber, JdDecisionRequest request, CancellationToken ct) => Execute(() => declarations.DecideDaAsync(referenceNumber, request, User.GetAccessScope(), ct));
    [Authorize(Roles = "JDCELLSS,SUPERADMIN")][HttpPost("{referenceNumber}/ss-acknowledge")] public Task<ActionResult<JdCaseListItem>> AcknowledgeSs(string referenceNumber, CancellationToken ct) => Execute(() => declarations.AcknowledgeSsAsync(referenceNumber, User.GetAccessScope(), ct));
    [Authorize(Roles = "JDCELLSS,SUPERADMIN")][HttpPost("{referenceNumber}/ss-decision")] public Task<ActionResult<JdCaseListItem>> DecideSs(string referenceNumber, JdDecisionRequest request, CancellationToken ct) => Execute(() => declarations.DecideSsAsync(referenceNumber, request, User.GetAccessScope(), ct));
    [HttpGet("{referenceNumber}/history")] public Task<IReadOnlyCollection<JdStatusHistoryItem>> History(string referenceNumber, CancellationToken ct) => declarations.HistoryAsync(referenceNumber, User.GetAccessScope(), ct);
    [HttpGet("report.csv")] public async Task<FileContentResult> Report([FromQuery] DateTime? from, [FromQuery] DateTime? to, CancellationToken ct) { var rows=await declarations.ReportAsync(from,to,User.GetAccessScope(),ct); var csv=new StringBuilder("Reference,Status,UAN,Member ID,Received,DA Decision,SS Decision,Rejection Reason\r\n"); foreach(var row in rows) csv.AppendLine(string.Join(',', new string?[] {row.ReferenceNumber,row.Status,row.Uan,row.MemberId,row.ReceivedAt.ToString("yyyy-MM-dd"),row.DaDecision,row.SsDecision,row.RejectionReason}.Select(value => $"\"{(value ?? string.Empty).Replace("\"","\"\"")}\""))); return File(Encoding.UTF8.GetBytes(csv.ToString()), "text/csv", $"jd-report-{DateTime.UtcNow:yyyyMMdd}.csv"); }
    private async Task<ActionResult<JdCaseListItem>> Execute(Func<Task<JdCaseListItem?>> operation) { try { return await operation() is { } item ? Ok(item) : NotFound(); } catch (ArgumentException error) { return BadRequest(new { message=error.Message }); } catch (InvalidOperationException error) { return Conflict(new { message=error.Message }); } }
}

