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
  cors_operation = {
    responses = {
      "200" = {
        description = "CORS response"
        headers = {
          "Access-Control-Allow-Headers" = { schema = { type = "string" } }
          "Access-Control-Allow-Methods" = { schema = { type = "string" } }
          "Access-Control-Allow-Origin"  = { schema = { type = "string" } }
        }
      }
    }
    "x-amazon-apigateway-integration" = {
      type = "mock"
      requestTemplates = {
        "application/json" = "{\"statusCode\": 200}"
      }
      responses = {
        default = {
          statusCode = "200"
          responseParameters = {
            "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
            "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,PATCH,DELETE,OPTIONS,HEAD'"
            "method.response.header.Access-Control-Allow-Origin"  = "'*'"
          }
        }
      }
    }
  }
}

data "aws_s3_object" "swagger" {
  bucket = var.swagger_s3_bucket
  key    = var.swagger_s3_key
}

locals {
  source_openapi = jsondecode(data.aws_s3_object.swagger.body)
  integrated_paths = {
    for path, path_item in local.source_openapi.paths : path => merge(
      {
        for verb, operation in path_item : verb => operation
        if !contains(["get", "put", "post", "delete", "options", "head", "patch"], lower(verb))
      },
      {
        for verb, operation in path_item : verb => merge(operation, {
          "x-amazon-apigateway-integration" = local.lambda_integration
        })
        if contains(["get", "put", "post", "delete", "options", "head", "patch"], lower(verb))
      },
      { options = local.cors_operation }
    )
  }
  imported_openapi = merge(local.source_openapi, {
    paths = local.integrated_paths
  })
}

resource "aws_api_gateway_rest_api" "this" {
  name              = var.api_name
  description       = "EPFO Grievance API (${var.environment})"
  body              = jsonencode(local.imported_openapi)
  put_rest_api_mode = "merge"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
  tags = local.tags
}

# Replaces the legacy VPC-endpoint deny policy so browser clients can reach
# this environment's regional gateway. Application endpoints remain protected
# by the Lambda's JWT and office-level authorization.
resource "aws_api_gateway_rest_api_policy" "public" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "execute-api:Invoke"
      Resource  = "execute-api:/${var.environment}/*/*"
    }]
  })
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowRegionalApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  triggers = {
    redeployment = sha1(jsonencode({
      openapi  = local.imported_openapi
      pipeline = var.deployment_trigger
    }))
  }
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_lambda_permission.api_gateway, aws_api_gateway_rest_api_policy.public]
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.environment
  tags          = local.tags
}
