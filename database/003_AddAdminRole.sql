IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleCode = N'ADMIN')
    INSERT dbo.Roles (RoleCode, DisplayName, IsActive) VALUES (N'ADMIN', N'Office Administrator', 1);
GO
