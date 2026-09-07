locals {
  environment        = get_env("DEPLOY_ENV")
  root_directory     = dirname(find_in_parent_folders("root.hcl"))
  environment_values = jsondecode(file("${local.root_directory}/env/${local.environment}/${local.environment}.tfvars.json"))
}

remote_state {
  backend = "s3"
  config = {
    bucket         = local.environment_values.tf_state_bucket_name
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = get_env("AWS_REGION", "ap-south-1")
    encrypt        = true
    dynamodb_table = local.environment_values.tf_lock_table_name
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.7.0"

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.0"
        }
      }
    }

    provider "aws" {
      region = var.aws_region
    }
  EOF
}
