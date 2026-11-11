# -----------------------------------------------------------------------------
# Aurora PostgreSQL Serverless v2
#
# The master password is generated and rotated by RDS in Secrets Manager
# (manage_master_user_password), so it never appears in Terraform state.
# Applications should prefer IAM database authentication: no password at all,
# just an rds-db:connect permission and a short-lived token.
# -----------------------------------------------------------------------------

# Newest available engine version for the requested major (or major.minor).
data "aws_rds_engine_version" "this" {
  engine  = "aurora-postgresql"
  version = var.engine_version_prefix
  latest  = true
}

resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "this" {
  name        = "${var.name}-db"
  description = "Aurora cluster ${var.name}"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-db" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "clients" {
  count = length(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.this.id
  description                  = "PostgreSQL from an allowed client"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = var.allowed_security_group_ids[count.index]
}

resource "aws_rds_cluster" "this" {
  cluster_identifier = var.name
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned" # Serverless v2 runs on the provisioned engine mode
  engine_version     = data.aws_rds_engine_version.this.version

  database_name               = var.database_name
  master_username             = var.master_username
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  iam_database_authentication_enabled = true
  storage_encrypted                   = true
  kms_key_id                          = var.kms_key_arn

  backup_retention_period         = var.backup_retention_period
  preferred_backup_window         = "02:00-03:00"
  preferred_maintenance_window    = "sun:03:30-sun:04:30"
  copy_tags_to_snapshot           = true
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = !var.deletion_protection
  final_snapshot_identifier       = var.deletion_protection ? "${var.name}-final" : null
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Engine upgrades are deliberate: bump engine_version_prefix, then apply.
  # Without this, a newer minor appearing in the data source would trigger one.
  lifecycle {
    ignore_changes = [engine_version]
  }
}

resource "aws_rds_cluster_instance" "this" {
  count = var.instance_count

  identifier         = "${var.name}-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  performance_insights_enabled = var.performance_insights_enabled
  auto_minor_version_upgrade   = true
}
