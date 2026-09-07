# EPFO infrastructure

This repository provisions EPFO Grievance infrastructure with Terraform and
Terragrunt. Reusable component configurations live directly under
`infrastructure/deploy/aws`; `infrastructure/deploy/aws/env` contains only the
dev and production JSON tfvars files.

## Architecture

1. `static` creates an encrypted S3 Terraform state bucket, DynamoDB lock table,
   encrypted artifact bucket, and a GitHub OIDC deployment role in each target
   account.
2. `vpc` creates public, private-app, and private-DB subnets. There is no NAT
   Gateway and no Transit Gateway. Interface endpoints for `execute-api` and
   `secretsmanager` keep API calls and database-secret retrieval private.
3. `rds` deploys SQL Server RDS into the private-DB subnets. It is not public and
   only accepts TCP/1433 from the Lambda security group.
4. `lambda` creates a separate encrypted, versioned package bucket and deploys
   the .NET API in the private-app subnets. It receives its SQL Server
   credentials from the RDS-managed Secrets Manager secret.
5. `apigw` imports the API OpenAPI JSON from the artifact bucket, injects the same
   `AWS_PROXY` Lambda integration for every operation, and exposes a private REST
   API through an execute-api interface VPC endpoint.

AWS API Gateway private integrations are for HTTP backends reached through a VPC
Link; they do not directly target Lambda. This implementation uses the supported
private REST API plus direct Lambda `AWS_PROXY` integration. Lambda and RDS stay
private, and no NAT is required.

## One-time bootstrap

The GitHub deployment role does not exist until `static` has run once. Use an
existing account-admin identity for this one-time command in each account:

```powershell
$env:AWS_REGION = "ap-south-1"
$env:EPFO_GITHUB_REPOSITORY = "Ramkrish26/epfo-grievance-summary-api"
Set-Location infrastructure/deploy/aws/static
$env:DEPLOY_ENV = "dev"
terragrunt --non-interactive init
terragrunt --non-interactive apply
```

The commands above use PowerShell syntax. In Command Prompt, set the variables
with `set DEPLOY_ENV=dev` before running Terragrunt. The artifact bucket name
is read from the environment tfvars file: `epfo-grievance-summary-dev-artifacts`
for dev and `epfo-grievance-summary-prd-artifacts` for production. The GitHub
repository is supplied through `EPFO_GITHUB_REPOSITORY`.

The deployment role trust policy uses GitHub's immutable owner and repository
IDs from the environment tfvars files. It permits only the matching GitHub
environment: `repo:Ramkrish26@39208833/epfo-grievance-summary-api@1358069775:environment:dev`
in the development account and the equivalent `:environment:prd` subject in
production.

If the GitHub OIDC provider was created manually, set its ARN as
`github_oidc_provider_arn` in that environment's tfvars file. This prevents
Terraform from attempting to create a duplicate provider. The development
configuration already references the provider in account `173291123230`.

Repeat for `prd`, changing the environment suffix. Store the emitted
`deployment_role_arn` in the appropriate GitHub secret afterwards.

## GitHub configuration

Repository variables:

- `AWS_DEV_ACCOUNT_ID`
- `AWS_PRD_ACCOUNT_ID`

Repository secrets:

- `AWS_DEV_DEPLOY_ROLE_ARN`
- `AWS_PRD_DEPLOY_ROLE_ARN`

The dev workflow runs for changes on `develop`. Production is manual-dispatch
only and uses the `prd` GitHub environment, where required reviewers should be
configured before use.

## Deployment workflow

After the one-time bootstrap, the reusable deployment workflow performs the
following for the selected environment:

1. Deploys the VPC and RDS prerequisites.
2. Creates the Lambda package bucket.
3. Restores, tests, and publishes the .NET 10 API for `linux-x64`.
4. Uploads `lambda.zip` and the generated OpenAPI document.
5. Plans and applies the remaining Lambda and API Gateway resources.

The dev workflow runs automatically for changes to `infrastructure/`, `.github/workflows/`,
`src/`, or `Epfo.Grievance.sln`. The production workflow is manual-dispatch only.
Each deployment run builds the API, creates or confirms the Lambda package
bucket, and uploads fresh Lambda and OpenAPI artifacts before applying Lambda
and API Gateway resources.

## Artifact contract

The deployment workflow creates the Lambda package bucket, builds the .NET
solution into the repository's `package/` directory, then uploads:

- `package/lambda.zip` to the Lambda-owned package bucket
- `package/swagger.json` to the static artifact bucket for API Gateway import

This sequence is automated before the Lambda and API Gateway deployment.

## Database initialization

Amazon RDS for SQL Server does not provide an initial-database setting. The
instance's generated master secret is injected into Lambda at deployment time.
After RDS is available, run the scripts in `database/` in numeric order from a
private-network SQL Server client or deployment job to create the
`EpfoGrievance` database and schema. For an existing database, run
`003_AddAdminRole.sql` and then `005_FeatureCompletion.sql` as described in
`database/README.md`. Edit the placeholders in `004_SeedInitialSuperAdmin.sql`
before running it. Do not place a database password in a tfvars file or GitHub
secret.

## Environment configuration

Review `infrastructure/deploy/aws/env/dev/dev.tfvars.json` and
`infrastructure/deploy/aws/env/prd/prd.tfvars.json` before applying. The production RDS engine
edition is SQL Server Standard so its Multi-AZ setting is supported; development
uses single-AZ SQL Server Express. AWS selects a supported engine patch version
when the version is not pinned in tfvars.
