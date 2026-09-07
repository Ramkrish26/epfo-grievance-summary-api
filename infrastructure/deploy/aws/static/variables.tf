variable "aws_region" { type = string }
variable "environment" { type = string }
variable "project" {
  type    = string
  default = "epfo"
}
variable "state_bucket_name" { type = string }
variable "artifact_bucket_name" { type = string }
variable "lock_table_name" { type = string }
variable "github_repository" { type = string }
variable "github_branch" { type = string }
variable "github_oidc_provider_arn" {
  type     = string
  default  = null
  nullable = true
}
variable "force_destroy_state_bucket" {
  type    = bool
  default = false
}
