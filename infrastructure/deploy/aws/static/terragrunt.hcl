include "root" { path = find_in_parent_folders("root.hcl") }

remote_state {
  backend = "local"
  config  = { path = "terraform.tfstate" }
}

locals {
  environment = get_env("DEPLOY_ENV")
  values      = jsondecode(file("${get_terragrunt_dir()}/../env/${local.environment}/${local.environment}.tfvars.json"))
}

terraform { source = "." }

inputs = {
  aws_region           = local.values.aws_region
  environment          = local.environment
  project              = local.values.project
  state_bucket_name    = local.values.tf_state_bucket_name
  artifact_bucket_name = local.values.artifact_bucket_name
  lock_table_name      = local.values.tf_lock_table_name
  github_repository    = get_env("EPFO_GITHUB_REPOSITORY")
  github_branch        = local.values.github_branch
}
