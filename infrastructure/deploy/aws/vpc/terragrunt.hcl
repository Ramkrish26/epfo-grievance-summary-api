include "root" { path = find_in_parent_folders("root.hcl") }

locals {
  environment = get_env("DEPLOY_ENV")
  values      = jsondecode(file("${get_terragrunt_dir()}/../env/${local.environment}/${local.environment}.tfvars.json"))
}

terraform { source = "." }

inputs = {
  aws_region               = local.values.aws_region
  environment              = local.environment
  project                  = local.values.project
  vpc_cidr                 = local.values.vpc_cidr
  availability_zones       = local.values.availability_zones
  public_subnet_cidrs      = local.values.public_subnet_cidrs
  private_app_subnet_cidrs = local.values.private_app_subnet_cidrs
  private_db_subnet_cidrs  = local.values.private_db_subnet_cidrs
  tags                     = local.values.tags
}
