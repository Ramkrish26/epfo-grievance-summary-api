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

inputs = {
  aws_region               = local.values.aws_region
  environment              = local.environment
  project                  = local.values.project
  lambda_s3_key            = local.values.lambda_s3_key
  lambda_s3_object_version = try(get_env("LAMBDA_PACKAGE_VERSION"), null)
  lambda_handler           = local.values.lambda_handler
  lambda_runtime           = local.values.lambda_runtime
  lambda_memory_size       = local.values.lambda_memory_size
  lambda_timeout_seconds   = local.values.lambda_timeout_seconds
  private_app_subnet_ids   = dependency.vpc.outputs.private_lambda_subnet_ids
  lambda_security_group_id = dependency.vpc.outputs.lambda_security_group_id
  db_endpoint              = dependency.rds.outputs.db_endpoint
  db_port                  = dependency.rds.outputs.db_port
  db_name                  = dependency.rds.outputs.db_name
  db_secret_arn            = dependency.rds.outputs.master_user_secret_arn
  cors_allowed_origins     = local.values.cors_allowed_origins
  tags                     = local.values.tags
}
