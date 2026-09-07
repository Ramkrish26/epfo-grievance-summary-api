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
  aws_region               = local.values.aws_region
  environment              = local.environment
  project                  = local.values.project
  state_bucket_name        = local.values.tf_state_bucket_name
  artifact_bucket_name     = local.values.artifact_bucket_name
  lock_table_name          = local.values.tf_lock_table_name
  github_repository        = get_env("EPFO_GITHUB_REPOSITORY")
  github_owner_id          = local.values.github_owner_id
  github_repository_id     = local.values.github_repository_id
  github_branch            = local.values.github_branch
  github_oidc_provider_arn = try(local.values.github_oidc_provider_arn, null)
}
