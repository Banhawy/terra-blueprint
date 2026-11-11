# Valkey (open-source Redis fork) replication group with encryption in transit
# and at rest. Clients must connect with TLS (valkeys:// / rediss://).

locals {
  major_version = split(".", var.engine_version)[0]
}

resource "aws_elasticache_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "this" {
  name        = "${var.name}-cache"
  description = "Valkey ${var.name}"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-cache" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "clients" {
  count = length(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.this.id
  description                  = "Valkey from an allowed client"
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = var.allowed_security_group_ids[count.index]
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.name
  description          = "Valkey cache ${var.name}"

  engine         = "valkey"
  engine_version = var.engine_version
  # The default group is fine until you need to tune Valkey; then create an
  # aws_elasticache_parameter_group and reference it here.
  # tflint-ignore: aws_elasticache_replication_group_default_parameter_group
  parameter_group_name = "default.valkey${local.major_version}"
  node_type            = var.node_type
  port                 = 6379

  # 1 node = no replica; 2+ = primary with replicas and automatic failover.
  num_cache_clusters         = var.node_count
  automatic_failover_enabled = var.node_count > 1
  multi_az_enabled           = var.node_count > 1

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.this.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn

  snapshot_retention_limit   = var.snapshot_retention_limit
  auto_minor_version_upgrade = true
  apply_immediately          = false
}
