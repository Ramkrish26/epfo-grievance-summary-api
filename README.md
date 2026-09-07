# EPFO Grievance Summary API

The clean-architecture solution is [Epfo.Grievance.sln](Epfo.Grievance.sln):

- `Domain` — business entities.
- `Application` — API contracts and use cases.
- `Infrastructure` — EF Core SQL Server context and implementations.
- `Api` — HTTP controllers, JWT authentication, CORS, and composition root.

## Local startup

1. Run the database scripts in numeric order against local SQL Server:
	`database/001_InitialSchema.sql`, `database/002_AddCaseAttributes.sql`,
	`database/003_AddAdminRole.sql`, `database/004_SeedInitialSuperAdmin.sql`,
	and `database/005_FeatureCompletion.sql`. Edit the placeholders in the seed
	script before running it. See [database/README.md](database/README.md) for
	migration guidance.
2. Copy `src/Epfo.Grievance.Api/appsettings.Development.example.json` to `appsettings.Development.json` in the same directory.
3. Set the SQL Server connection string, a unique JWT key (at least 32 characters), and a local bootstrap-admin password.
4. Run:

```powershell
dotnet run --project src/Epfo.Grievance.Api
```

The bootstrap account is created only in Development, only if the `Users` table is empty, and only when both bootstrap credentials are supplied. Delete the bootstrap settings after creating normal users.

## UI endpoints

- `GET /api/auth/offices`
- `POST /api/auth/login`
- `POST /api/auth/signup`
- `POST /api/auth/switch-office` (Super Admin)
- `GET /api/dashboard/summary`
- `GET /api/modules/{moduleId}/records?search=...`
- `POST /api/modules/{moduleId}/records`
- `GET /api/cases/{referenceNumber}`
- `GET /api/cases/{referenceNumber}/history`
- `PATCH /api/cases/{referenceNumber}/status`
- `POST /api/jd-intake`
- `GET /api/jd-cases?stage=all`
- `POST /api/jd-cases/{referenceNumber}/da-acknowledge`
- `POST /api/jd-cases/{referenceNumber}/da-decision`
- `POST /api/jd-cases/{referenceNumber}/ss-acknowledge`
- `POST /api/jd-cases/{referenceNumber}/ss-decision`
- `GET /api/jd-cases/{referenceNumber}/history`
- `GET /api/jd-cases/report.csv`
- `GET /api/users/reference-data`
- `GET /api/users`
- `POST /api/users`
- `PATCH /api/users/{userId}/role`
- `PATCH /api/users/{userId}/status`
- `GET /health`

## AWS packaging

`package/` is a CI staging folder, not application source. It is cleared on
each pipeline run and contains the published Lambda files, `lambda.zip`, the
generated `swagger.json`, and the temporary API log. Its contents are ignored
by Git.

The deployment workflow restores and tests the solution, publishes the API for
.NET 10 on the `linux-x64` Lambda runtime, creates `package/lambda.zip`, and
generates `package/swagger.json` from `/openapi/v1.json`. The Lambda ZIP is
uploaded to the Lambda-owned package bucket. The OpenAPI document is uploaded
to the static artifact bucket configured once in the environment file:
`epfo-grievance-summary-dev-artifacts` for development and
`epfo-grievance-summary-prd-artifacts` for production. Terraform and the
reusable deployment workflow read the same configuration; no `EPFO_ARTIFACT_BUCKET`
environment variable is required.
