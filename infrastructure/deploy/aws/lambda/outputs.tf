output "lambda_arn" { value = aws_lambda_function.this.arn }
output "lambda_invoke_arn" { value = aws_lambda_function.this.invoke_arn }
output "lambda_function_name" { value = aws_lambda_function.this.function_name }
output "lambda_role_arn" { value = aws_iam_role.this.arn }
output "package_bucket_name" { value = aws_s3_bucket.packages.bucket }
