using Epfo.Grievance.Application;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Epfo.Grievance.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/modules/{moduleId}/records")]
public sealed class ModuleRecordsController(ICaseService cases) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyCollection<CaseListItem>>> Get(string moduleId, [FromQuery] string? search, CancellationToken ct)
    { try { return Ok(await cases.ListAsync(moduleId, search, User.GetAccessScope(), ct)); } catch (UnauthorizedAccessException) { return Forbid(); } catch (ArgumentException error) { return BadRequest(new { message = error.Message }); } }

    [HttpGet("/api/modules/{moduleId}/report.csv")]
    public async Task<ActionResult> Report(string moduleId, [FromQuery] string? search, CancellationToken ct)
    { try { var rows=await cases.ReportAsync(moduleId,search,User.GetAccessScope(),ct); var keys=rows.SelectMany(x=>x.Fields.Keys).Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(x=>x).ToArray(); var csv=new StringBuilder(); csv.AppendLine(string.Join(',',new[]{"Reference","Status","Received"}.Concat(keys).Select(Csv))); foreach(var row in rows)csv.AppendLine(string.Join(',',new[]{row.ReferenceNumber,row.Status,row.ReceivedAt.ToString("O")}.Concat(keys.Select(key=>row.Fields.GetValueOrDefault(key))).Select(Csv))); return File(Encoding.UTF8.GetBytes(csv.ToString()),"text/csv",$"{moduleId}-report-{DateTime.UtcNow:yyyyMMdd}.csv"); } catch(UnauthorizedAccessException){return Forbid();} catch(ArgumentException error){return BadRequest(new{message=error.Message});} }

    [HttpPost]
    public async Task<ActionResult<CaseDetails>> Create(string moduleId, CreateCaseRequest request, CancellationToken ct)
    {
        try { var created = await cases.CreateAsync(moduleId, request, User.GetAccessScope(), ct); return CreatedAtAction(nameof(GetByReference), new { referenceNumber = created.ReferenceNumber }, created); }
        catch (ArgumentException error) { return BadRequest(new { message = error.Message }); }
        catch (UnauthorizedAccessException) { return Forbid(); }
    }

    [HttpGet("/api/cases/{referenceNumber}")]
    public async Task<ActionResult<CaseDetails>> GetByReference(string referenceNumber, CancellationToken ct) => (await cases.GetAsync(referenceNumber, User.GetAccessScope(), ct)) is { } item ? Ok(item) : NotFound();

    [HttpGet("/api/cases/{referenceNumber}/history")]
    public async Task<ActionResult<IReadOnlyCollection<CaseStatusHistoryItem>>> History(string referenceNumber, CancellationToken ct) => (await cases.HistoryAsync(referenceNumber,User.GetAccessScope(),ct)) is { } items ? Ok(items) : NotFound();

    [HttpPatch("/api/cases/{referenceNumber}/status")]
    public async Task<ActionResult<CaseDetails>> ChangeStatus(string referenceNumber, ChangeCaseStatusRequest request, CancellationToken ct) => (await cases.ChangeStatusAsync(referenceNumber, request, User.GetAccessScope(), ct)) is { } item ? Ok(item) : NotFound();

    private static string Csv(string? value) => $"\"{(value??string.Empty).Replace("\"","\"\"")}\"";
}
