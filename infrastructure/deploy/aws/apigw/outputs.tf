output "api_id" { value = aws_api_gateway_rest_api.this.id }
output "private_invoke_url" { value = "https://${aws_api_gateway_rest_api.this.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.this.stage_name}" }
output "private_api_vpc_endpoint_id" { value = var.execute_api_vpc_endpoint_id }

