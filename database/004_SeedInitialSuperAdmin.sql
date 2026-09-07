/*
  Development/initial-install seed only. Run after 001_InitialSchema.sql and 003_AddAdminRole.sql.
  It creates the enabled superadmin account only when that username does not already exist.
  Initial credentials: superadmin / ChangeMe!2026Secure
  Replace this script's password hash with a securely generated one before production use.
*/
USE [EpfoGrievance];
GO

SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF EXISTS (SELECT 1 FROM dbo.Users WHERE Username = N'superadmin')
BEGIN
    PRINT 'The superadmin account already exists. No changes were made.';
    COMMIT TRANSACTION;
    RETURN;
END;

DECLARE @OfficeId INT = (SELECT OfficeId FROM dbo.Offices WHERE OfficeCode = N'RO-ROY' AND IsActive = 1);
DECLARE @RoleId SMALLINT = (SELECT RoleId FROM dbo.Roles WHERE RoleCode = N'SUPERADMIN' AND IsActive = 1);
IF @OfficeId IS NULL OR @RoleId IS NULL
    THROW 51001, 'The RO-ROY office or SUPERADMIN role is missing.', 1;

DECLARE @UserId BIGINT;
INSERT dbo.Users (OfficeId, Username, Email, DisplayName, PasswordHash, IsEnabled)
VALUES (@OfficeId, N'superadmin', N'superadmin@epfo.local', N'Initial Super Admin',
        N'AQAAAAIAAYagAAAAEOd/JjaxbsBKRs1zfACwEn7IGCx7mJTOqXPcpzkrw4Qe6zdfTFW5GjQdpI/Ke9dDsQ==', 1);
SET @UserId = SCOPE_IDENTITY();

INSERT dbo.UserRoles (UserId, RoleId, AssignedByUserId)
VALUES (@UserId, @RoleId, @UserId);

COMMIT TRANSACTION;
GO
