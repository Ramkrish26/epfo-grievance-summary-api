variable "aws_region" { type = string }
variable "environment" { type = string }
variable "project" {
  type    = string
  default = "epfo"
}
variable "vpc_cidr" { type = string }
variable "availability_zones" { type = list(string) }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_app_subnet_cidrs" { type = list(string) }
variable "private_db_subnet_cidrs" { type = list(string) }
variable "db_port" {
  type    = number
  default = 1433
}
variable "tags" {
  type    = map(string)
  default = {}
}
