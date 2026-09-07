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
    vpc_id                = "vpc-00000000"
    private_db_subnet_ids = ["subnet-00000000", "subnet-00000001"]
    rds_security_group_id = "sg-00000000"
  }
}

inputs = {
  aws_region               = local.values.aws_region
  environment              = local.environment
  project                  = local.values.project
  vpc_id                   = dependency.vpc.outputs.vpc_id
  private_db_subnet_ids    = dependency.vpc.outputs.private_db_subnet_ids
  rds_security_group_id    = dependency.vpc.outputs.rds_security_group_id
  db_instance_class        = local.values.db_instance_class
  db_allocated_storage     = local.values.db_allocated_storage
  db_max_allocated_storage = local.values.db_max_allocated_storage
  db_name                  = local.values.db_name
  db_master_username       = local.values.db_master_username
  db_engine                = local.values.db_engine
  multi_az                 = local.values.multi_az
  deletion_protection      = local.values.deletion_protection
  skip_final_snapshot      = local.values.skip_final_snapshot
  tags                     = local.values.tags
}
