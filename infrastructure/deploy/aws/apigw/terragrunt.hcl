include "root" { path = find_in_parent_folders("root.hcl") }

locals {
  environment = get_env("DEPLOY_ENV")
  values      = jsondecode(file("${get_terragrunt_dir()}/../env/${local.environment}/${local.environment}.tfvars.json"))
}

terraform { source = "." }

dependency "vpc" {
  config_path                             = "../vpc"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs                            = { execute_api_vpc_endpoint_id = "vpce-00000000" }
}

dependency "lambda" {
  config_path                             = "../lambda"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    lambda_arn           = "arn:aws:lambda:ap-south-1:000000000000:function:placeholder"
    lambda_invoke_arn    = "arn:aws:apigateway:ap-south-1:lambda:path/2015-03-31/functions/placeholder/invocations"
    lambda_function_name = "placeholder"
  }
}

inputs = {
  aws_region                  = local.values.aws_region
  environment                 = local.environment
  project                     = local.values.project
  api_name                    = local.values.api_name
  swagger_s3_bucket           = local.values.artifact_bucket_name
  swagger_s3_key              = local.values.swagger_s3_key
  lambda_arn                  = dependency.lambda.outputs.lambda_arn
  lambda_invoke_arn           = dependency.lambda.outputs.lambda_invoke_arn
  lambda_function_name        = dependency.lambda.outputs.lambda_function_name
  execute_api_vpc_endpoint_id = dependency.vpc.outputs.execute_api_vpc_endpoint_id
  tags                        = local.values.tags
}
