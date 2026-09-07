locals {
  name                = "${var.project}-${var.environment}-api"
  package_bucket_name = "${var.project}-${var.environment}-lambda-packages-${data.aws_caller_identity.current.account_id}"
  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

data "aws_caller_identity" "current" {}

resource "random_password" "jwt_signing_key" {
  length           = 64
  special          = true
  override_special = "_-"
}

resource "aws_secretsmanager_secret" "jwt_signing_key" {
  name                    = "${local.name}-jwt-signing-key"
  description             = "JWT signing key for the ${local.name} Lambda API"
  recovery_window_in_days = 7
  tags                    = local.tags
}

resource "aws_secretsmanager_secret_version" "jwt_signing_key" {
  secret_id     = aws_secretsmanager_secret.jwt_signing_key.id
  secret_string = random_password.jwt_signing_key.result
}

resource "aws_s3_bucket" "packages" {
  bucket        = local.package_bucket_name
  force_destroy = false
  tags          = merge(local.tags, { Name = local.package_bucket_name, Purpose = "lambda-packages" })
}

resource "aws_s3_bucket_versioning" "packages" {
  bucket = aws_s3_bucket.packages.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "packages" {
  bucket = aws_s3_bucket.packages.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "packages" {
  bucket                  = aws_s3_bucket.packages.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "packages_tls" {
  bucket = aws_s3_bucket.packages.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.packages.arn, "${aws_s3_bucket.packages.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${local.name}-lambda"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "secret" {
  name = "read-rds-master-secret"
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.db_secret_arn, aws_secretsmanager_secret.jwt_signing_key.arn]
    }]
  })
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${local.name}"
  retention_in_days = var.environment == "prd" ? 90 : 30
  tags              = local.tags
}

resource "aws_lambda_function" "this" {
  function_name = local.name
  description   = "EPFO Grievance .NET API (${var.environment})"
  role          = aws_iam_role.this.arn
  runtime       = var.lambda_runtime
  handler       = var.lambda_handler

  s3_bucket         = aws_s3_bucket.packages.id
  s3_key            = var.lambda_s3_key
  s3_object_version = var.lambda_s3_object_version
  memory_size       = var.lambda_memory_size
  timeout           = var.lambda_timeout_seconds

  reserved_concurrent_executions = -1

  vpc_config {
    subnet_ids         = var.private_app_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = merge({
      ASPNETCORE_ENVIRONMENT = var.environment == "prd" ? "Production" : "Development"
      Database__SecretArn    = var.db_secret_arn
      Database__Endpoint     = var.db_endpoint
      Database__Port         = tostring(var.db_port)
      Database__Name         = var.db_name
      Jwt__SecretArn         = aws_secretsmanager_secret.jwt_signing_key.arn
      Jwt__Issuer            = "Epfo.Grievance.Api"
      Jwt__Audience          = "Epfo.Grievance.Ui"
      }, {
      for index, origin in var.cors_allowed_origins : "Cors__AllowedOrigins__${index}" => origin
    })
  }

  depends_on = [aws_cloudwatch_log_group.this, aws_secretsmanager_secret_version.jwt_signing_key]
  tags       = local.tags
}
