using Epfo.Grievance.Application;
using Epfo.Grievance.Domain;
using Microsoft.EntityFrameworkCore;

namespace Epfo.Grievance.Infrastructure;

public sealed class JointDeclarationService(EpfoDbContext db) : IJointDeclarationService
{
    public async Task<JdCaseListItem> CreateIntakeAsync(CreateCaseRequest request, AccessScope scope, CancellationToken ct)
    {
        if (!scope.IsAdmin && !scope.IsSuperAdmin && !scope.Roles.Contains("RECEIPT", StringComparer.OrdinalIgnoreCase))
            throw new UnauthorizedAccessException("Only Receipt, Admin, or Super Admin users can register a physical joint declaration.");

        string Required(string key, string label) => request.Fields.TryGetValue(key, out var value) && !string.IsNullOrWhiteSpace(value)
            ? value.Trim()
            : throw new ArgumentException($"{label} is required.");

        var memberId = Required("member_id", "Member ID");
        var group = Required("account_group", "Accounts group");
        var task = Required("task", "Task");
        var declarationType = Required("declaration_type", "Type of correction");
        var uan = request.Fields.GetValueOrDefault("uan")?.Trim();
        if (!string.IsNullOrWhiteSpace(uan) && !System.Text.RegularExpressions.Regex.IsMatch(uan, @"^\d{12}$"))
            throw new ArgumentException("UAN must contain exactly 12 digits.");
        if (!await db.Offices.AnyAsync(x => x.OfficeId == scope.OfficeId && x.IsActive, ct))
            throw new UnauthorizedAccessException("The assigned office is unavailable.");

        var type = await db.CaseTypes.SingleAsync(x => x.TypeCode == "JOINT_DECLARATION" && x.IsActive, ct);
        var status = await db.CaseStatuses.SingleAsync(x => x.StatusCode == "NEW", ct);
        var enclosureNames = request.Fields
            .Where(x => x.Key.StartsWith("document_", StringComparison.OrdinalIgnoreCase) && string.Equals(x.Value, "true", StringComparison.OrdinalIgnoreCase))
            .Select(x => x.Key[9..].Replace('_', ' '))
            .ToArray();
        var item = new GrievanceCase
        {
            ReferenceNumber = $"EPFO-JD-{DateTime.UtcNow:yyyyMMdd}-{Guid.NewGuid().ToString("N")[..6].ToUpperInvariant()}",
            OfficeId = scope.OfficeId,
            CaseTypeId = type.CaseTypeId,
            CaseType = type,
            CaseStatusId = status.CaseStatusId,
            CaseStatus = status,
            Uan = string.IsNullOrWhiteSpace(uan) ? null : uan,
            MemberId = memberId,
            ReceivedAt = DateTime.UtcNow,
            CreatedAt = DateTime.UtcNow,
            CreatedByUserId = scope.UserId,
            Remarks = request.Fields.GetValueOrDefault("remarks")?.Trim(),
            JointDeclarationDetail = new JointDeclarationDetail
            {
                DeclarationType = declarationType,
                GroupName = group,
                TaskName = task,
                EnclosureNotes = enclosureNames.Length == 0 ? "No enclosures recorded" : string.Join(", ", enclosureNames)
            },
            Attributes = request.Fields
                .Where(x => x.Key.StartsWith("document_", StringComparison.OrdinalIgnoreCase))
                .Select(x => new CaseAttribute { AttributeName = x.Key, AttributeValue = x.Value })
                .ToList()
        };
        item.JointDeclarationDetail.Case = item;
        db.Cases.Add(item);
        await db.SaveChangesAsync(ct);
        db.CaseStatusHistory.Add(new CaseStatusHistory { CaseId = item.CaseId, CaseStatusId = status.CaseStatusId, ChangedByUserId = scope.UserId, ChangedAt = DateTime.UtcNow, Remarks = "Physical joint declaration registered by Receipt" });
        await db.SaveChangesAsync(ct);
        return ToListItem(item);
    }

    public async Task<IReadOnlyCollection<JdCaseListItem>> ListAsync(string stage, AccessScope scope, CancellationToken ct)
    {
        IQueryable<GrievanceCase> query = BaseQuery(scope);
        query = stage.ToLowerInvariant() switch {
            "da-ack" => query.Where(x => x.JointDeclarationDetail == null || x.JointDeclarationDetail.DeoReceivedAt == null),
            "da-process" => query.Where(x => x.JointDeclarationDetail != null && x.JointDeclarationDetail.DeoReceivedAt != null && x.JointDeclarationDetail.DeoDecision == null),
            "ss-ack" => query.Where(x => x.JointDeclarationDetail != null && x.JointDeclarationDetail.DeoDecision == "APPROVED" && x.JointDeclarationDetail.SsReceivedAt == null),
            "ss-process" => query.Where(x => x.JointDeclarationDetail != null && x.JointDeclarationDetail.SsReceivedAt != null && x.JointDeclarationDetail.SsDecision == null),
            "rejected" => query.Where(x => x.JointDeclarationDetail != null && (x.JointDeclarationDetail.DeoDecision == "REJECTED" || x.JointDeclarationDetail.SsDecision == "REJECTED")),
            _ => query
        };
        return await query.OrderByDescending(x => x.ReceivedAt).Select(ToListItem()).ToListAsync(ct);
    }

    public async Task<JdCaseListItem?> AcknowledgeDaAsync(string reference, AccessScope scope, CancellationToken ct)
    {
        var item = await FindAsync(reference, scope, ct); if (item is null) return null;
        var detail = EnsureDetail(item); if (detail.DeoReceivedAt is not null) throw new InvalidOperationException("JD Cell has already acknowledged this declaration.");
        detail.DeoReceivedAt = DateTime.UtcNow; detail.AcknowledgedByUserId = scope.UserId; await SetStatusAsync(item, "ACKNOWLEDGED", "Acknowledged by JD Cell", scope.UserId, ct); return ToListItem(item);
    }

    public async Task<JdCaseListItem?> DecideDaAsync(string reference, JdDecisionRequest request, AccessScope scope, CancellationToken ct)
    {
        var item = await FindAsync(reference, scope, ct); if (item is null) return null; var detail = EnsureDetail(item); ValidateDecision(request);
        if (detail.DeoReceivedAt is null) throw new InvalidOperationException("JD Cell must acknowledge the declaration before processing it."); if (detail.DeoDecision is not null) throw new InvalidOperationException("JD Cell has already processed this declaration.");
        detail.DeoDecision = request.Decision.ToUpperInvariant(); detail.DeoProcessedAt = DateTime.UtcNow; detail.ProcessedByUserId = scope.UserId; if (detail.DeoDecision == "REJECTED") detail.RejectionReason = request.RejectionReason;
        await SetStatusAsync(item, detail.DeoDecision == "APPROVED" ? "IN_PROGRESS" : "REJECTED", $"JD Cell {detail.DeoDecision.ToLowerInvariant()}: {request.RejectionReason}", scope.UserId, ct); return ToListItem(item);
    }

    public async Task<JdCaseListItem?> AcknowledgeSsAsync(string reference, AccessScope scope, CancellationToken ct)
    {
        var item = await FindAsync(reference, scope, ct); if (item is null) return null; var detail = EnsureDetail(item);
        if (detail.DeoDecision != "APPROVED") throw new InvalidOperationException("JD Cell SS can acknowledge only after JD Cell approval."); if (detail.SsReceivedAt is not null) throw new InvalidOperationException("JD Cell SS has already acknowledged this declaration.");
        detail.SsReceivedAt = DateTime.UtcNow; await SetStatusAsync(item, "ACKNOWLEDGED", "Acknowledged by JD Cell SS", scope.UserId, ct); return ToListItem(item);
    }

    public async Task<JdCaseListItem?> DecideSsAsync(string reference, JdDecisionRequest request, AccessScope scope, CancellationToken ct)
    {
        var item = await FindAsync(reference, scope, ct); if (item is null) return null; var detail = EnsureDetail(item); ValidateDecision(request);
        if (detail.SsReceivedAt is null) throw new InvalidOperationException("JD Cell SS must acknowledge the declaration before processing it."); if (detail.SsDecision is not null) throw new InvalidOperationException("JD Cell SS has already processed this declaration.");
        detail.SsDecision = request.Decision.ToUpperInvariant(); detail.SsProcessedAt = DateTime.UtcNow; if (detail.SsDecision == "REJECTED") detail.RejectionReason = request.RejectionReason;
        await SetStatusAsync(item, detail.SsDecision, $"JD Cell SS {detail.SsDecision.ToLowerInvariant()}: {request.RejectionReason}", scope.UserId, ct); return ToListItem(item);
    }

    public async Task<IReadOnlyCollection<JdStatusHistoryItem>> HistoryAsync(string reference, AccessScope scope, CancellationToken ct) => await (from history in db.CaseStatusHistory join item in db.Cases on history.CaseId equals item.CaseId join status in db.CaseStatuses on history.CaseStatusId equals status.CaseStatusId where item.ReferenceNumber == reference && item.OfficeId == scope.OfficeId orderby history.ChangedAt descending select new JdStatusHistoryItem(status.StatusCode, history.Remarks, history.ChangedAt)).ToListAsync(ct);
    public async Task<IReadOnlyCollection<JdCaseListItem>> ReportAsync(DateTime? from, DateTime? to, AccessScope scope, CancellationToken ct) { var query = BaseQuery(scope); if (from is not null) query = query.Where(x => x.ReceivedAt >= from); if (to is not null) query = query.Where(x => x.ReceivedAt < to.Value.AddDays(1)); return await query.OrderByDescending(x => x.ReceivedAt).Select(ToListItem()).ToListAsync(ct); }

    private IQueryable<GrievanceCase> BaseQuery(AccessScope scope) => db.Cases.Include(x => x.CaseStatus).Include(x => x.JointDeclarationDetail).Where(x => x.CaseType.TypeCode == "JOINT_DECLARATION" && x.OfficeId == scope.OfficeId);
    private Task<GrievanceCase?> FindAsync(string reference, AccessScope scope, CancellationToken ct) => BaseQuery(scope).SingleOrDefaultAsync(x => x.ReferenceNumber == reference, ct);
    private static JointDeclarationDetail EnsureDetail(GrievanceCase item) { if (item.JointDeclarationDetail is not null) return item.JointDeclarationDetail; var detail = new JointDeclarationDetail { CaseId = item.CaseId, Case = item }; item.JointDeclarationDetail = detail; return detail; }
    private async Task SetStatusAsync(GrievanceCase item, string statusCode, string remarks, long userId, CancellationToken ct) { var status = await db.CaseStatuses.SingleAsync(x => x.StatusCode == statusCode, ct); item.CaseStatusId = status.CaseStatusId; item.CaseStatus = status; item.ClosedAt = status.IsClosed ? DateTime.UtcNow : null; db.CaseStatusHistory.Add(new CaseStatusHistory { CaseId = item.CaseId, CaseStatusId = status.CaseStatusId, ChangedByUserId = userId, ChangedAt = DateTime.UtcNow, Remarks = remarks }); await db.SaveChangesAsync(ct); }
    private static void ValidateDecision(JdDecisionRequest request) { var decision = request.Decision.ToUpperInvariant(); if (decision is not ("APPROVED" or "REJECTED")) throw new ArgumentException("Decision must be APPROVED or REJECTED."); if (decision == "REJECTED" && string.IsNullOrWhiteSpace(request.RejectionReason)) throw new ArgumentException("A rejection reason is required."); }
    private static System.Linq.Expressions.Expression<Func<GrievanceCase, JdCaseListItem>> ToListItem() => x => new JdCaseListItem(x.ReferenceNumber, x.CaseStatus.StatusCode, x.Uan, x.MemberId, x.ReceivedAt, x.JointDeclarationDetail == null ? null : x.JointDeclarationDetail.DeoReceivedAt, x.JointDeclarationDetail == null ? null : x.JointDeclarationDetail.DeoDecision, x.JointDeclarationDetail == null ? null : x.JointDeclarationDetail.SsReceivedAt, x.JointDeclarationDetail == null ? null : x.JointDeclarationDetail.SsDecision, x.JointDeclarationDetail == null ? null : x.JointDeclarationDetail.RejectionReason);
    private static JdCaseListItem ToListItem(GrievanceCase x) => new(x.ReferenceNumber, x.CaseStatus.StatusCode, x.Uan, x.MemberId, x.ReceivedAt, x.JointDeclarationDetail?.DeoReceivedAt, x.JointDeclarationDetail?.DeoDecision, x.JointDeclarationDetail?.SsReceivedAt, x.JointDeclarationDetail?.SsDecision, x.JointDeclarationDetail?.RejectionReason);
}
