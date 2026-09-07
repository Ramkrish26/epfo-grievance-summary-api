output "vpc_id" { value = aws_vpc.this.id }
output "private_lambda_subnet_ids" { value = aws_subnet.private_app[*].id }
output "private_db_subnet_ids" { value = aws_subnet.private_db[*].id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "lambda_security_group_id" { value = aws_security_group.lambda.id }
output "rds_security_group_id" { value = aws_security_group.rds.id }
output "execute_api_vpc_endpoint_id" { value = aws_vpc_endpoint.execute_api.id }

