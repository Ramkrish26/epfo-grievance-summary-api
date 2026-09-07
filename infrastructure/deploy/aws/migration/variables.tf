variable "aws_region" { type = string }
variable "enabled" {
  type    = bool
  default = false
}
variable "environment" { type = string }
variable "project" {
  type    = string
  default = "epfo"
}
variable "package_bucket_name" { type = string }
variable "migration_s3_key" {
  type     = string
  default  = null
  nullable = true
}
variable "migration_s3_object_version" {
  type     = string
  default  = null
  nullable = true
}
variable "migration_handler" {
  type    = string
  default = "Epfo.Grievance.Migrations::Epfo.Grievance.Migrations.Function::FunctionHandler"
}
variable "private_app_subnet_ids" { type = list(string) }
variable "lambda_security_group_id" { type = string }
variable "db_endpoint" { type = string }
variable "db_port" { type = number }
variable "db_name" { type = string }
variable "db_secret_arn" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
