locals {
  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
  lambda_integration = {
    type                = "aws_proxy"
    httpMethod          = "POST"
    uri                 = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.lambda_arn}/invocations"
    passthroughBehavior = "when_no_match"
  }
}

data "aws_s3_object" "swagger" {
  bucket = var.swagger_s3_bucket
  key    = var.swagger_s3_key
}

locals {
  source_openapi = jsondecode(data.aws_s3_object.swagger.body)
  integrated_paths = {
    for path, path_item in local.source_openapi.paths : path => {
      for verb, operation in path_item : verb => contains(["get", "put", "post", "delete", "options", "head", "patch"], lower(verb)) ? merge(operation, {
        "x-amazon-apigateway-integration" = local.lambda_integration
      }) : operation
    }
  }
  imported_openapi = merge(local.source_openapi, {
    paths = local.integrated_paths
    "x-amazon-apigateway-endpoint-configuration" = {
      vpcEndpointIds = [var.execute_api_vpc_endpoint_id]
    }
  })
}

resource "aws_api_gateway_rest_api" "this" {
  name              = var.api_name
  description       = "EPFO Grievance API (${var.environment})"
  body              = jsonencode(local.imported_openapi)
  put_rest_api_mode = "merge"

  endpoint_configuration {
    types            = ["PRIVATE"]
    vpc_endpoint_ids = [var.execute_api_vpc_endpoint_id]
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Deny"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "execute-api:/*"
        Condition = {
          StringNotEquals = { "aws:SourceVpce" = var.execute_api_vpc_endpoint_id }
        }
      },
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "execute-api:/*"
      }
    ]
  })
  tags = local.tags
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowPrivateApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  triggers = {
    redeployment = sha1(jsonencode(local.imported_openapi))
  }
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_lambda_permission.api_gateway]
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.environment
  tags          = local.tags
}
