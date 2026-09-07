variable "aws_region" { type = string }
variable "environment" { type = string }
variable "project" {
  type    = string
  default = "epfo"
}
variable "lambda_s3_key" { type = string }
variable "lambda_s3_object_version" {
  type    = string
  default = null
}
variable "lambda_handler" { type = string }
variable "lambda_runtime" {
  type    = string
  default = "dotnet10"
}
variable "lambda_memory_size" {
  type    = number
  default = 1024
}
variable "lambda_timeout_seconds" {
  type    = number
  default = 30
}
variable "private_app_subnet_ids" { type = list(string) }
variable "lambda_security_group_id" { type = string }
variable "db_endpoint" { type = string }
variable "db_port" { type = number }
variable "db_name" { type = string }
variable "db_secret_arn" { type = string }
variable "cors_allowed_origins" {
  type    = list(string)
  default = []
}
variable "tags" {
  type    = map(string)
  default = {}
}
