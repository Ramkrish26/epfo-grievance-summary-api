IF OBJECT_ID(N'dbo.CaseAttributes', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CaseAttributes (
        CaseAttributeId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CaseAttributes PRIMARY KEY,
        CaseId BIGINT NOT NULL CONSTRAINT FK_CaseAttributes_Cases REFERENCES dbo.Cases(CaseId),
        AttributeName NVARCHAR(100) NOT NULL,
        AttributeValue NVARCHAR(MAX) NULL,
        CONSTRAINT UQ_CaseAttributes_Case_Attribute UNIQUE (CaseId, AttributeName)
    );
END;
GO
