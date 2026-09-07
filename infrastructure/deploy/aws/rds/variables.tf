variable "aws_region" { type = string }
variable "environment" { type = string }
variable "project" {
  type    = string
  default = "epfo"
}
variable "vpc_id" { type = string }
variable "private_db_subnet_ids" { type = list(string) }
variable "rds_security_group_id" { type = string }
variable "db_instance_class" { type = string }
variable "db_allocated_storage" { type = number }
variable "db_max_allocated_storage" { type = number }
variable "db_name" {
  type    = string
  default = "EpfoGrievance"
}
variable "db_master_username" {
  type    = string
  default = "epfoadmin"
}
variable "db_engine" {
  type    = string
  default = "sqlserver-ex"
}
variable "db_engine_version" {
  type     = string
  default  = null
  nullable = true
}
variable "multi_az" {
  type    = bool
  default = false
}
variable "deletion_protection" {
  type    = bool
  default = true
}
variable "skip_final_snapshot" {
  type    = bool
  default = false
}
variable "tags" {
  type    = map(string)
  default = {}
}
