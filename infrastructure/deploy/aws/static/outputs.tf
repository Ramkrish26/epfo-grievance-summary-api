output "state_bucket_name" { value = aws_s3_bucket.state.bucket }
output "lock_table_name" { value = aws_dynamodb_table.lock.name }
output "artifact_bucket_name" { value = aws_s3_bucket.artifacts.bucket }
output "deployment_role_arn" { value = aws_iam_role.github_deploy.arn }

