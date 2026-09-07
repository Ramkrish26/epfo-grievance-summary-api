locals {
  name = "${var.project}-${var.environment}"
  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-db"
  subnet_ids = var.private_db_subnet_ids
  tags       = merge(local.tags, { Name = "${local.name}-db-subnets" })
}

resource "aws_db_instance" "this" {
  identifier            = "${local.name}-sqlserver"
  engine                = var.db_engine
  engine_version        = var.db_engine_version
  license_model         = "license-included"
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  # SQL Server does not support RDS's initial DBName setting. The application
  # database is created by its EF Core migration after this instance is ready.
  username                    = var.db_master_username
  manage_master_user_password = true
  port                        = 1433
  db_subnet_group_name        = aws_db_subnet_group.this.name
  vpc_security_group_ids      = [var.rds_security_group_id]
  publicly_accessible         = false
  multi_az                    = var.multi_az
  backup_retention_period     = var.environment == "prd" ? 7 : 1
  deletion_protection         = var.deletion_protection
  skip_final_snapshot         = var.skip_final_snapshot
  copy_tags_to_snapshot       = true
  auto_minor_version_upgrade  = true
  tags                        = merge(local.tags, { Name = "${local.name}-sqlserver" })
}
