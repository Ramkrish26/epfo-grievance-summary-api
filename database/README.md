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

The deployment pipeline runs versioned scripts from a short-lived migration
Lambda inside the VPC. It uses the RDS-managed master secret and does not put
database credentials in GitHub or Terraform configuration.

## Script order

For a new database, the pipeline applies the scripts in numeric order and stores
each filename and SHA-256 hash in `dbo.__EpfoSchemaMigrations`. A script that is
already recorded with the same hash is skipped. Changing an already-recorded
script causes a failure; add a new, higher-numbered file instead.

`004_SeedInitialSuperAdmin.sql` is run by the migration pipeline like the other
versioned scripts. Edit its placeholders before dispatching the initial
migration run when creating the first Super Admin.

Use the manually triggered **Run database migrations** workflow after the
infrastructure deployment has completed. It packages every versioned script,
creates the migration Lambda after RDS is ready, and destroys the Lambda after
either a successful or failed run. The migration ledger and SHA-256 hash check
mean previously applied scripts are skipped, while a changed applied script
causes the workflow to fail. There is no force-migration option.

For an existing database created before the role and feature updates, run these
idempotent migrations in order:

1. `003_AddAdminRole.sql`
2. `005_FeatureCompletion.sql`
3. `006_AddRoyapettahAndAmbatturOffices.sql`

`005_FeatureCompletion.sql` adds the APFC review case type and improves the
office/type/status query index. It intentionally preserves existing office
names because office labels distinguish office-level access.

All authenticated application queries are scoped using the office identifier in
the validated JWT. A Super Admin must switch to an office before managing or
querying that office; an Admin remains restricted to their assigned office.
