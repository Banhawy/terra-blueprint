# -----------------------------------------------------------------------------
# web-api: a containerised HTTP API
#
#   internet -> WAF -> ALB (TLS) -> ECS Fargate tasks -> Aurora PostgreSQL
#                                                     -> Valkey
#                                                     -> S3 uploads bucket
#
# Composes components from ../../components. Alerting (alerting.tf),
# scheduled jobs (scheduled-tasks.tf), IAM (permissions.tf) and DNS (dns.tf)
# live in their own files.
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # Secret key "app-secret-key" becomes env var APP_SECRET_KEY.
  app_secret_env = {
    for k, arn in module.secrets.secret_arns : upper(replace(k, "-", "_")) => arn
  }

  # With IAM auth the app connects as a dedicated user with a short-lived token
  # and no password. Without it, it reads the RDS-managed master credentials.
  database_env = merge(
    {
      DATABASE_HOST     = module.database.cluster_endpoint
      DATABASE_PORT     = tostring(module.database.port)
      DATABASE_NAME     = module.database.database_name
      DATABASE_IAM_AUTH = tostring(var.db_use_iam_auth)
    },
    var.db_use_iam_auth ? { DATABASE_USER = var.db_app_username } : {},
  )
  database_secrets = var.db_use_iam_auth ? {} : {
    DATABASE_USER     = "${module.database.master_user_secret_arn}:username::"
    DATABASE_PASSWORD = "${module.database.master_user_secret_arn}:password::"
  }

  environment = merge(
    local.database_env,
    {
      PORT           = tostring(var.container_port)
      CACHE_URL      = "valkeys://${module.cache.primary_endpoint}:${module.cache.port}/0"
      UPLOADS_BUCKET = module.uploads.bucket_name
      AWS_REGION     = data.aws_region.current.region
    },
    var.extra_environment,
  )

  secrets = merge(local.app_secret_env, local.database_secrets, var.extra_secrets)

  # No distinct(): over not-yet-created ARNs it would make the list length
  # unknown at plan time, and the ecs-service component counts on it.
  secret_arns = concat(
    values(module.secrets.secret_arns),
    var.db_use_iam_auth ? [] : [module.database.master_user_secret_arn],
    var.extra_secret_arns,
  )
}

# --- Edge: load balancer, routing, WAF ----------------------------------------

module "alb" {
  source = "../../components/alb"

  name                = var.name
  vpc_id              = var.vpc_id
  vpc_cidr            = var.vpc_cidr
  subnet_ids          = var.public_subnet_ids
  certificate_arn     = var.certificate_arn
  deletion_protection = var.deletion_protection
}

resource "aws_lb_target_group" "app" {
  name                 = var.name
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = var.health_check_path
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
}

resource "aws_lb_listener_rule" "app" {
  listener_arn = module.alb.https_listener_arn
  priority     = 100

  condition {
    host_header {
      values = [var.hostname]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

module "waf" {
  count  = var.waf_enabled ? 1 : 0
  source = "../../components/waf"

  name                     = var.name
  scope                    = "REGIONAL"
  associated_resource_arns = [module.alb.arn]
  managed_rule_groups      = var.waf_managed_rule_groups

  rate_limit_rules = [{
    name           = "per-ip"
    priority       = 100
    limit          = var.waf_rate_limit_per_5min
    window_seconds = 300
  }]
}

# --- Compute -------------------------------------------------------------------

module "app" {
  source = "../../components/ecs-service"

  name       = var.name
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  image          = "${var.image_repository}:${var.image_tag}"
  container_port = var.container_port
  cpu            = var.cpu
  memory         = var.memory

  environment = local.environment
  secrets     = local.secrets
  secret_arns = local.secret_arns

  desired_count = var.min_capacity
  min_capacity  = var.min_capacity
  max_capacity  = var.max_capacity

  target_group_arn                  = aws_lb_target_group.app.arn
  allowed_security_group_ids        = [module.alb.security_group_id]
  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  depends_on = [aws_lb_listener_rule.app]
}

# --- Data ----------------------------------------------------------------------

module "database" {
  source = "../../components/aurora-postgresql"

  name                       = var.name
  database_name              = var.db_name
  vpc_id                     = var.vpc_id
  subnet_ids                 = var.database_subnet_ids
  allowed_security_group_ids = [module.app.security_group_id]
  min_capacity               = var.db_min_capacity
  max_capacity               = var.db_max_capacity
  instance_count             = var.db_instance_count
  deletion_protection        = var.deletion_protection
}

module "cache" {
  source = "../../components/elasticache"

  name                       = var.name
  vpc_id                     = var.vpc_id
  subnet_ids                 = var.database_subnet_ids
  allowed_security_group_ids = [module.app.security_group_id]
  node_type                  = var.cache_node_type
  node_count                 = var.cache_node_count
}

module "uploads" {
  source = "../../components/s3"

  bucket_name   = "${var.name}-uploads-${data.aws_caller_identity.current.account_id}"
  force_destroy = !var.deletion_protection
  cors_rules = length(var.uploads_cors_origins) == 0 ? [] : [{
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = var.uploads_cors_origins
  }]
  lifecycle_rules = [{
    id                                 = "expire-old-versions"
    noncurrent_version_expiration_days = 30
  }]
}

module "secrets" {
  source = "../../components/secretmanager"

  name_prefix             = var.name
  secrets                 = var.app_secrets
  recovery_window_in_days = var.deletion_protection ? 30 : 0
}
