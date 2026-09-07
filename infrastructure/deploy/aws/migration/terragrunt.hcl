include "root" { path = find_in_parent_folders("root.hcl") }

locals {
  environment = get_env("DEPLOY_ENV")
  values      = jsondecode(file("${get_terragrunt_dir()}/../env/${local.environment}/${local.environment}.tfvars.json"))
}

terraform { source = "." }

dependency "vpc" {
  config_path                             = "../vpc"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    private_lambda_subnet_ids = ["subnet-00000000", "subnet-00000001"]
    lambda_security_group_id  = "sg-00000000"
  }
}

dependency "rds" {
  config_path                             = "../rds"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    db_endpoint            = "placeholder.database.local"
    db_port                = 1433
    db_name                = "EpfoGrievance"
    master_user_secret_arn = "arn:aws:secretsmanager:ap-south-1:000000000000:secret:placeholder"
  }
}

dependency "lambda" {
  config_path                             = "../lambda"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    package_bucket_name = "placeholder-lambda-packages"
  }
}

inputs = {
  aws_region                  = local.values.aws_region
  enabled                     = get_env("RUN_DATABASE_MIGRATIONS", "false") == "true"
  environment                 = local.environment
  project                     = local.values.project
  package_bucket_name         = dependency.lambda.outputs.package_bucket_name
  migration_s3_key            = try(get_env("MIGRATION_S3_KEY"), null)
  migration_s3_object_version = try(get_env("MIGRATION_S3_OBJECT_VERSION"), null)
  private_app_subnet_ids      = dependency.vpc.outputs.private_lambda_subnet_ids
  lambda_security_group_id    = dependency.vpc.outputs.lambda_security_group_id
  db_endpoint                 = dependency.rds.outputs.db_endpoint
  db_port                     = dependency.rds.outputs.db_port
  db_name                     = dependency.rds.outputs.db_name
  db_secret_arn               = dependency.rds.outputs.master_user_secret_arn
  tags                        = local.values.tags
}
