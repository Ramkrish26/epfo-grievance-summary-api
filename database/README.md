# Database schema

`001_InitialSchema.sql` creates the consolidated `EpfoGrievance` SQL Server database.

It replaces the legacy MySQL database split with a normalized case model. The legacy workflows map to `Cases` plus their detail tables:

| Legacy workflow | New tables |
|---|---|
| JD / receipt processing | `Cases`, `JointDeclarationDetails`, `CaseDocuments`, `CaseStatusHistory` |
| Telecalling / APFC escalation | `Cases`, `TelecallingDetails`, `TelecallActivities` |
| DCMC / DCMC receipts | `Cases`, `DcmcDetails`, `CaseDocuments` |
| Thappal / pension | `Cases`, `CorrespondenceEntries` |
| Compliance | `Cases`, `ComplianceDockets` |
| Login and roles | `Users`, `Roles`, `UserRoles`, `PasswordResetTokens` |

Run the script in SQL Server Management Studio or Azure Data Studio using an account that can create databases. It creates no user account and stores no credentials.

## Script order

For a new database, run the scripts in numeric order. Edit the placeholders in
`004_SeedInitialSuperAdmin.sql` before running it; this is the only supported way
to create the first Super Admin.

For an existing database created before the role and feature updates, run these
idempotent migrations in order:

1. `003_AddAdminRole.sql`
2. `005_FeatureCompletion.sql`

`005_FeatureCompletion.sql` adds the APFC review case type and improves the
office/type/status query index. It intentionally preserves existing office
names because office labels distinguish office-level access.

All authenticated application queries are scoped using the office identifier in
the validated JWT. A Super Admin must switch to an office before managing or
querying that office; an Admin remains restricted to their assigned office.
