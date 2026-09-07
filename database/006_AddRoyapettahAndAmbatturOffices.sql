/* Rename the existing Royapettah office and add the Ambattur office. */
USE [EpfoGrievance];
GO

SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF NOT EXISTS (SELECT 1 FROM dbo.Offices WHERE OfficeCode = N'RO-ROY')
    THROW 51002, 'The existing RO-ROY office is missing.', 1;

UPDATE dbo.Offices
SET OfficeName = N'EPFO Regional Office - Royapettah'
WHERE OfficeCode = N'RO-ROY'
  AND OfficeName <> N'EPFO Regional Office - Royapettah';

IF NOT EXISTS (SELECT 1 FROM dbo.Offices WHERE OfficeCode = N'RO-AMB')
    INSERT dbo.Offices (OfficeCode, OfficeName, City)
    VALUES (N'RO-AMB', N'EPFO Regional Office - Ambattur', N'Ambattur');

COMMIT TRANSACTION;
GO
