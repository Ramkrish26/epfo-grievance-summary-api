variable "aws_region" { type = string }
variable "environment" { type = string }
variable "project" {
  type    = string
  default = "epfo"
}
variable "api_name" { type = string }
variable "swagger_s3_bucket" { type = string }
variable "swagger_s3_key" { type = string }
variable "lambda_arn" { type = string }
variable "lambda_invoke_arn" { type = string }
variable "lambda_function_name" { type = string }
variable "cors_allowed_origin" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
