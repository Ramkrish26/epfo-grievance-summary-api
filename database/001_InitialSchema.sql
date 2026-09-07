/*
  EPFO Grievance Summary: consolidated SQL Server schema.
  Execute with a SQL Server login permitted to create databases.
*/
IF DB_ID(N'EpfoGrievance') IS NULL
    CREATE DATABASE [EpfoGrievance];
GO
USE [EpfoGrievance];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
GO

CREATE TABLE dbo.Offices (
    OfficeId            INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Offices PRIMARY KEY,
    OfficeCode          NVARCHAR(30) NOT NULL CONSTRAINT UQ_Offices_OfficeCode UNIQUE,
    OfficeName          NVARCHAR(160) NOT NULL,
    City                NVARCHAR(100) NOT NULL,
    IsActive            BIT NOT NULL CONSTRAINT DF_Offices_IsActive DEFAULT (1),
    CreatedAt           DATETIME2(0) NOT NULL CONSTRAINT DF_Offices_CreatedAt DEFAULT (SYSUTCDATETIME())
);

CREATE TABLE dbo.Roles (
    RoleId              SMALLINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Roles PRIMARY KEY,
    RoleCode            NVARCHAR(40) NOT NULL CONSTRAINT UQ_Roles_RoleCode UNIQUE,
    DisplayName         NVARCHAR(100) NOT NULL,
    IsActive            BIT NOT NULL CONSTRAINT DF_Roles_IsActive DEFAULT (1)
);

CREATE TABLE dbo.Users (
    UserId              BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
    OfficeId            INT NOT NULL CONSTRAINT FK_Users_Offices REFERENCES dbo.Offices(OfficeId),
    Username            NVARCHAR(100) NOT NULL CONSTRAINT UQ_Users_Username UNIQUE,
    Email               NVARCHAR(254) NULL CONSTRAINT UQ_Users_Email UNIQUE,
    DisplayName         NVARCHAR(160) NOT NULL,
    PasswordHash        NVARCHAR(512) NOT NULL,
    IsEnabled           BIT NOT NULL CONSTRAINT DF_Users_IsEnabled DEFAULT (1),
    LastLoginAt         DATETIME2(0) NULL,
    CreatedAt           DATETIME2(0) NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt           DATETIME2(0) NULL,
    RowVersion          ROWVERSION NOT NULL
);

CREATE TABLE dbo.UserRoles (
    UserId              BIGINT NOT NULL CONSTRAINT FK_UserRoles_Users REFERENCES dbo.Users(UserId),
    RoleId              SMALLINT NOT NULL CONSTRAINT FK_UserRoles_Roles REFERENCES dbo.Roles(RoleId),
    AssignedAt          DATETIME2(0) NOT NULL CONSTRAINT DF_UserRoles_AssignedAt DEFAULT (SYSUTCDATETIME()),
    AssignedByUserId    BIGINT NULL CONSTRAINT FK_UserRoles_AssignedBy REFERENCES dbo.Users(UserId),
    CONSTRAINT PK_UserRoles PRIMARY KEY (UserId, RoleId)
);

CREATE TABLE dbo.PasswordResetTokens (
    PasswordResetTokenId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PasswordResetTokens PRIMARY KEY,
    UserId               BIGINT NOT NULL CONSTRAINT FK_PasswordResetTokens_Users REFERENCES dbo.Users(UserId),
    TokenHash            NVARCHAR(512) NOT NULL CONSTRAINT UQ_PasswordResetTokens_TokenHash UNIQUE,
    ExpiresAt            DATETIME2(0) NOT NULL,
    UsedAt               DATETIME2(0) NULL,
    CreatedAt            DATETIME2(0) NOT NULL CONSTRAINT DF_PasswordResetTokens_CreatedAt DEFAULT (SYSUTCDATETIME())
);

CREATE TABLE dbo.CaseTypes (
    CaseTypeId          SMALLINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CaseTypes PRIMARY KEY,
    TypeCode            NVARCHAR(40) NOT NULL CONSTRAINT UQ_CaseTypes_TypeCode UNIQUE,
    DisplayName         NVARCHAR(100) NOT NULL,
    IsActive            BIT NOT NULL CONSTRAINT DF_CaseTypes_IsActive DEFAULT (1)
);

CREATE TABLE dbo.ServiceAreas (
    ServiceAreaId       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ServiceAreas PRIMARY KEY,
    AreaCode            NVARCHAR(50) NOT NULL CONSTRAINT UQ_ServiceAreas_AreaCode UNIQUE,
    DisplayName         NVARCHAR(160) NOT NULL,
    IsActive            BIT NOT NULL CONSTRAINT DF_ServiceAreas_IsActive DEFAULT (1)
);

CREATE TABLE dbo.CaseStatuses (
    CaseStatusId        SMALLINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CaseStatuses PRIMARY KEY,
    StatusCode          NVARCHAR(30) NOT NULL CONSTRAINT UQ_CaseStatuses_StatusCode UNIQUE,
    DisplayName         NVARCHAR(80) NOT NULL,
    IsClosed            BIT NOT NULL CONSTRAINT DF_CaseStatuses_IsClosed DEFAULT (0),
    SortOrder           SMALLINT NOT NULL
);

CREATE TABLE dbo.Cases (
    CaseId              BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Cases PRIMARY KEY,
    ReferenceNumber     NVARCHAR(80) NOT NULL CONSTRAINT UQ_Cases_ReferenceNumber UNIQUE,
    OfficeId            INT NOT NULL CONSTRAINT FK_Cases_Offices REFERENCES dbo.Offices(OfficeId),
    CaseTypeId          SMALLINT NOT NULL CONSTRAINT FK_Cases_CaseTypes REFERENCES dbo.CaseTypes(CaseTypeId),
    ServiceAreaId       INT NULL CONSTRAINT FK_Cases_ServiceAreas REFERENCES dbo.ServiceAreas(ServiceAreaId),
    CaseStatusId        SMALLINT NOT NULL CONSTRAINT FK_Cases_CaseStatuses REFERENCES dbo.CaseStatuses(CaseStatusId),
    Uan                 CHAR(12) NULL,
    MemberId            NVARCHAR(30) NULL,
    EstablishmentCode   NVARCHAR(30) NULL,
    PpoNumber           NVARCHAR(30) NULL,
    MemberName          NVARCHAR(160) NULL,
    MobileNumber        NVARCHAR(20) NULL,
    Email               NVARCHAR(254) NULL,
    Subject             NVARCHAR(500) NULL,
    Remarks             NVARCHAR(MAX) NULL,
    ReceivedAt          DATETIME2(0) NOT NULL CONSTRAINT DF_Cases_ReceivedAt DEFAULT (SYSUTCDATETIME()),
    DueAt               DATETIME2(0) NULL,
    ClosedAt            DATETIME2(0) NULL,
    CreatedByUserId     BIGINT NULL CONSTRAINT FK_Cases_CreatedBy REFERENCES dbo.Users(UserId),
    UpdatedByUserId     BIGINT NULL CONSTRAINT FK_Cases_UpdatedBy REFERENCES dbo.Users(UserId),
    CreatedAt           DATETIME2(0) NOT NULL CONSTRAINT DF_Cases_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt           DATETIME2(0) NULL,
    RowVersion          ROWVERSION NOT NULL,
    CONSTRAINT CK_Cases_Uan CHECK (Uan IS NULL OR Uan NOT LIKE '%[^0-9]%')
);
CREATE INDEX IX_Cases_Type_Status_ReceivedAt ON dbo.Cases(CaseTypeId, CaseStatusId, ReceivedAt DESC);
CREATE INDEX IX_Cases_Uan ON dbo.Cases(Uan) WHERE Uan IS NOT NULL;
CREATE INDEX IX_Cases_MemberId ON dbo.Cases(MemberId) WHERE MemberId IS NOT NULL;

CREATE TABLE dbo.CaseAssignments (
    CaseAssignmentId    BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CaseAssignments PRIMARY KEY,
    CaseId              BIGINT NOT NULL CONSTRAINT FK_CaseAssignments_Cases REFERENCES dbo.Cases(CaseId),
    AssignedToUserId    BIGINT NOT NULL CONSTRAINT FK_CaseAssignments_AssignedTo REFERENCES dbo.Users(UserId),
    AssignedByUserId    BIGINT NULL CONSTRAINT FK_CaseAssignments_AssignedBy REFERENCES dbo.Users(UserId),
    AssignedAt          DATETIME2(0) NOT NULL CONSTRAINT DF_CaseAssignments_AssignedAt DEFAULT (SYSUTCDATETIME()),
    ReleasedAt          DATETIME2(0) NULL,
    Notes               NVARCHAR(1000) NULL
);
CREATE INDEX IX_CaseAssignments_Open ON dbo.CaseAssignments(AssignedToUserId, AssignedAt DESC) WHERE ReleasedAt IS NULL;

CREATE TABLE dbo.CaseStatusHistory (
    CaseStatusHistoryId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CaseStatusHistory PRIMARY KEY,
    CaseId              BIGINT NOT NULL CONSTRAINT FK_CaseStatusHistory_Cases REFERENCES dbo.Cases(CaseId),
    CaseStatusId        SMALLINT NOT NULL CONSTRAINT FK_CaseStatusHistory_Statuses REFERENCES dbo.CaseStatuses(CaseStatusId),
    ChangedByUserId     BIGINT NULL CONSTRAINT FK_CaseStatusHistory_Users REFERENCES dbo.Users(UserId),
    Remarks             NVARCHAR(2000) NULL,
    ChangedAt           DATETIME2(0) NOT NULL CONSTRAINT DF_CaseStatusHistory_ChangedAt DEFAULT (SYSUTCDATETIME())
);
CREATE INDEX IX_CaseStatusHistory_Case_ChangedAt ON dbo.CaseStatusHistory(CaseId, ChangedAt DESC);

CREATE TABLE dbo.CaseDocuments (
    CaseDocumentId      BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CaseDocuments PRIMARY KEY,
    CaseId              BIGINT NOT NULL CONSTRAINT FK_CaseDocuments_Cases REFERENCES dbo.Cases(CaseId),
    DocumentType        NVARCHAR(80) NOT NULL,
    OriginalFileName    NVARCHAR(260) NOT NULL,
    StorageKey          NVARCHAR(600) NOT NULL CONSTRAINT UQ_CaseDocuments_StorageKey UNIQUE,
    ContentType         NVARCHAR(120) NULL,
    FileSizeBytes       BIGINT NULL,
    IsReceived          BIT NOT NULL CONSTRAINT DF_CaseDocuments_IsReceived DEFAULT (1),
    UploadedByUserId    BIGINT NULL CONSTRAINT FK_CaseDocuments_Users REFERENCES dbo.Users(UserId),
    UploadedAt          DATETIME2(0) NOT NULL CONSTRAINT DF_CaseDocuments_UploadedAt DEFAULT (SYSUTCDATETIME())
);
CREATE INDEX IX_CaseDocuments_Case ON dbo.CaseDocuments(CaseId, DocumentType);

CREATE TABLE dbo.JointDeclarationDetails (
    CaseId                  BIGINT NOT NULL CONSTRAINT PK_JointDeclarationDetails PRIMARY KEY CONSTRAINT FK_JointDeclarationDetails_Cases REFERENCES dbo.Cases(CaseId),
    DeclarationType         NVARCHAR(80) NULL,
    GroupName               NVARCHAR(100) NULL,
    TaskName                NVARCHAR(160) NULL,
    EnclosureNotes          NVARCHAR(1000) NULL,
    DeoReceivedAt           DATETIME2(0) NULL,
    DeoProcessedAt          DATETIME2(0) NULL,
    DeoDecision             NVARCHAR(30) NULL,
    SsReceivedAt            DATETIME2(0) NULL,
    SsProcessedAt           DATETIME2(0) NULL,
    SsDecision              NVARCHAR(30) NULL,
    RejectionReason         NVARCHAR(2000) NULL,
    AcknowledgedByUserId    BIGINT NULL CONSTRAINT FK_JointDeclarationDetails_AcknowledgedBy REFERENCES dbo.Users(UserId),
    ProcessedByUserId       BIGINT NULL CONSTRAINT FK_JointDeclarationDetails_ProcessedBy REFERENCES dbo.Users(UserId)
);

CREATE TABLE dbo.TelecallingDetails (
    CaseId                  BIGINT NOT NULL CONSTRAINT PK_TelecallingDetails PRIMARY KEY CONSTRAINT FK_TelecallingDetails_Cases REFERENCES dbo.Cases(CaseId),
    CallType                NVARCHAR(80) NOT NULL,
    IsImportant             BIT NOT NULL CONSTRAINT DF_TelecallingDetails_IsImportant DEFAULT (0),
    IsEscalated             BIT NOT NULL CONSTRAINT DF_TelecallingDetails_IsEscalated DEFAULT (0),
    EscalatedAt             DATETIME2(0) NULL,
    EscalationNotes         NVARCHAR(2000) NULL,
    LastFollowUpAt          DATETIME2(0) NULL
);

CREATE TABLE dbo.TelecallActivities (
    TelecallActivityId      BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TelecallActivities PRIMARY KEY,
    CaseId                  BIGINT NOT NULL CONSTRAINT FK_TelecallActivities_Cases REFERENCES dbo.Cases(CaseId),
    CallAt                  DATETIME2(0) NOT NULL CONSTRAINT DF_TelecallActivities_CallAt DEFAULT (SYSUTCDATETIME()),
    Outcome                 NVARCHAR(80) NOT NULL,
    Notes                   NVARCHAR(2000) NULL,
    CreatedByUserId         BIGINT NULL CONSTRAINT FK_TelecallActivities_Users REFERENCES dbo.Users(UserId)
);
CREATE INDEX IX_TelecallActivities_Case_CallAt ON dbo.TelecallActivities(CaseId, CallAt DESC);

CREATE TABLE dbo.DcmcDetails (
    CaseId                  BIGINT NOT NULL CONSTRAINT PK_DcmcDetails PRIMARY KEY CONSTRAINT FK_DcmcDetails_Cases REFERENCES dbo.Cases(CaseId),
    SealDate                DATE NULL,
    ClaimStatus             NVARCHAR(80) NULL,
    ClaimDateOfExit         DATE NULL,
    ClaimDateOfDeath        DATE NULL,
    NatureOfDeath           NVARCHAR(160) NULL,
    LcmStatus               NVARCHAR(80) NULL,
    CorrectionType          NVARCHAR(160) NULL,
    AcGroup                 NVARCHAR(100) NULL,
    TaskName                NVARCHAR(160) NULL,
    RejectionReason         NVARCHAR(2000) NULL,
    AadhaarClaim            BIT NULL,
    BirthCertificate        BIT NULL,
    Photograph              BIT NULL,
    DeathCertificate        BIT NULL,
    SurvivingCertificate    BIT NULL,
    BankPassbook            BIT NULL,
    EsiBenefits             BIT NULL,
    EmployerSignature       BIT NULL,
    ENomination             BIT NULL
);

CREATE TABLE dbo.CorrespondenceEntries (
    CaseId                  BIGINT NOT NULL CONSTRAINT PK_CorrespondenceEntries PRIMARY KEY CONSTRAINT FK_CorrespondenceEntries_Cases REFERENCES dbo.Cases(CaseId),
    EntryCategory           NVARCHAR(80) NOT NULL,
    SectionName             NVARCHAR(120) NULL,
    GroupTask               NVARCHAR(160) NULL,
    ComplaintArea           NVARCHAR(160) NULL,
    ReceivedFrom            NVARCHAR(200) NULL,
    SenderReference         NVARCHAR(120) NULL,
    ReferenceLetterDate     DATE NULL,
    ExternalReferenceId     NVARCHAR(120) NULL
);

CREATE TABLE dbo.ComplianceDockets (
    CaseId                  BIGINT NOT NULL CONSTRAINT PK_ComplianceDockets PRIMARY KEY CONSTRAINT FK_ComplianceDockets_Cases REFERENCES dbo.Cases(CaseId),
    DocketKind              NVARCHAR(20) NOT NULL,
    DairyNumber             NVARCHAR(80) NULL,
    ReportingMonth          TINYINT NULL,
    ReportingYear           SMALLINT NULL,
    IrNir                   NVARCHAR(10) NULL,
    OfficerName             NVARCHAR(160) NULL,
    AreaCode                NVARCHAR(30) NULL,
    Amount                  DECIMAL(18,2) NULL,
    RecoveryStatus          NVARCHAR(40) NULL,
    CONSTRAINT CK_ComplianceDockets_Kind CHECK (DocketKind IN ('INQUIRY','DEMAND','COLLECTION')),
    CONSTRAINT CK_ComplianceDockets_Month CHECK (ReportingMonth IS NULL OR ReportingMonth BETWEEN 1 AND 12)
);
CREATE INDEX IX_ComplianceDockets_Report ON dbo.ComplianceDockets(DocketKind, ReportingYear, ReportingMonth, IrNir, AreaCode);

CREATE TABLE dbo.AuditEvents (
    AuditEventId            BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AuditEvents PRIMARY KEY,
    UserId                  BIGINT NULL CONSTRAINT FK_AuditEvents_Users REFERENCES dbo.Users(UserId),
    EntityName              NVARCHAR(100) NOT NULL,
    EntityId                NVARCHAR(100) NOT NULL,
    Action                  NVARCHAR(40) NOT NULL,
    BeforeJson              NVARCHAR(MAX) NULL,
    AfterJson               NVARCHAR(MAX) NULL,
    IpAddress               NVARCHAR(64) NULL,
    OccurredAt              DATETIME2(0) NOT NULL CONSTRAINT DF_AuditEvents_OccurredAt DEFAULT (SYSUTCDATETIME())
);
CREATE INDEX IX_AuditEvents_Entity ON dbo.AuditEvents(EntityName, EntityId, OccurredAt DESC);
GO

INSERT dbo.Offices (OfficeCode, OfficeName, City) VALUES (N'RO-ROY', N'EPFO Regional Office', N'Regional Office');
INSERT dbo.Roles (RoleCode, DisplayName) VALUES
(N'JDCELL', N'JD Cell'), (N'JDCELLSS', N'JD Cell SS'), (N'COUNTER', N'Counter'), (N'TELECALLING', N'Telecalling'),
(N'RECEIPT', N'Receipt'), (N'WHATSAPP', N'WhatsApp'), (N'APFC', N'APFC'), (N'THAPPAL', N'Thappal'),
(N'COMPLIANCE', N'Compliance'), (N'DCMC', N'DCMC'), (N'PENSION', N'Pension'), (N'ADMIN', N'Office Administrator'), (N'SUPERADMIN', N'Super Admin');
INSERT dbo.CaseTypes (TypeCode, DisplayName) VALUES
(N'JOINT_DECLARATION', N'Joint Declaration'), (N'TELECALL', N'Telecalling'), (N'DCMC_CLAIM', N'DCMC Claim'),
(N'DCMC_RECEIPT', N'DCMC Receipt'), (N'THAPPAL', N'Thappal'), (N'PENSION', N'Pension'),
(N'RECEIPT', N'Receipt'), (N'COMPLIANCE_INQUIRY', N'Compliance Inquiry'),
(N'COMPLIANCE_DEMAND', N'Compliance Demand'), (N'COMPLIANCE_COLLECTION', N'Compliance Collection'),
(N'WHATSAPP', N'WhatsApp Grievance'), (N'COUNTER', N'Counter Grievance'), (N'APFC_REVIEW', N'APFC Review');
INSERT dbo.CaseStatuses (StatusCode, DisplayName, IsClosed, SortOrder) VALUES
(N'NEW', N'New', 0, 10), (N'ACKNOWLEDGED', N'Acknowledged', 0, 20), (N'IN_PROGRESS', N'In Progress', 0, 30),
(N'PENDING_DOCUMENTS', N'Pending Documents', 0, 40), (N'ESCALATED', N'Escalated', 0, 50),
(N'APPROVED', N'Approved', 1, 80), (N'REJECTED', N'Rejected', 1, 90), (N'CLOSED', N'Closed', 1, 100);
COMMIT TRANSACTION;
GO

CREATE OR ALTER VIEW dbo.vw_OpenCaseSummary AS
SELECT c.CaseId, c.ReferenceNumber, ct.TypeCode, ct.DisplayName AS CaseType, cs.StatusCode,
       c.Uan, c.MemberId, c.MemberName, c.ReceivedAt, c.DueAt, o.OfficeName
FROM dbo.Cases c
JOIN dbo.CaseTypes ct ON ct.CaseTypeId = c.CaseTypeId
JOIN dbo.CaseStatuses cs ON cs.CaseStatusId = c.CaseStatusId
JOIN dbo.Offices o ON o.OfficeId = c.OfficeId
WHERE cs.IsClosed = 0;
GO
