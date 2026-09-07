output "api_id" { value = aws_api_gateway_rest_api.this.id }
output "invoke_url" { value = "https://${aws_api_gateway_rest_api.this.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.this.stage_name}" }
