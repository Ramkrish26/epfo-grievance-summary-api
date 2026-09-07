USE [EpfoGrievance];
GO

IF NOT EXISTS (SELECT 1 FROM dbo.CaseTypes WHERE TypeCode=N'APFC_REVIEW')
    INSERT dbo.CaseTypes (TypeCode,DisplayName,IsActive) VALUES (N'APFC_REVIEW',N'APFC Review',1);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Cases') AND name=N'IX_Cases_Office_Type_Status_ReceivedAt')
    CREATE INDEX IX_Cases_Office_Type_Status_ReceivedAt ON dbo.Cases(OfficeId,CaseTypeId,CaseStatusId,ReceivedAt DESC);
GO
