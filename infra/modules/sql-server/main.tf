resource "aws_db_subnet_group" "database" {
  name       = var.name
  subnet_ids = var.subnet_ids
}

resource "aws_cloudwatch_log_group" "errors" {
  name              = "/aws/rds/instance/${var.name}/error"
  retention_in_days = 14
}

resource "aws_db_instance" "sql_server" {
  identifier     = var.name
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class
  license_model  = "license-included"

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  username                    = "dbadmin"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.database.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period         = var.backup_retention_days
  copy_tags_to_snapshot           = true
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = var.skip_final_snapshot
  final_snapshot_identifier       = var.skip_final_snapshot ? null : "${var.name}-final"
  enabled_cloudwatch_logs_exports = ["error"]
  auto_minor_version_upgrade      = true
  apply_immediately               = true

  depends_on = [aws_cloudwatch_log_group.errors]
}
