locals {
  name = "${var.project}-${var.environment}-db-migrator"
  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "database-migration"
  })
}

data "aws_iam_policy_document" "assume" {
  count = var.enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  count              = var.enabled ? 1 : 0
  name               = "${local.name}-lambda"
  assume_role_policy = data.aws_iam_policy_document.assume[0].json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "logs" {
  count      = var.enabled ? 1 : 0
  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc" {
  count      = var.enabled ? 1 : 0
  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "secret" {
  count = var.enabled ? 1 : 0
  name  = "read-rds-master-secret"
  role  = aws_iam_role.this[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = var.db_secret_arn
    }]
  })
}

resource "aws_cloudwatch_log_group" "this" {
  count             = var.enabled ? 1 : 0
  name              = "/aws/lambda/${local.name}"
  retention_in_days = var.environment == "prd" ? 90 : 30
  tags              = local.tags
}

resource "aws_lambda_function" "this" {
  count         = var.enabled ? 1 : 0
  function_name = local.name
  description   = "Short-lived EPFO database migration runner (${var.environment})"
  role          = aws_iam_role.this[0].arn
  runtime       = "dotnet10"
  handler       = var.migration_handler

  s3_bucket         = var.package_bucket_name
  s3_key            = var.migration_s3_key
  s3_object_version = var.migration_s3_object_version
  memory_size       = 1024
  timeout           = 900

  vpc_config {
    subnet_ids         = var.private_app_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      Database__SecretArn = var.db_secret_arn
      Database__Endpoint  = var.db_endpoint
      Database__Port      = tostring(var.db_port)
      Database__Name      = var.db_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.this]
  tags       = local.tags
}
