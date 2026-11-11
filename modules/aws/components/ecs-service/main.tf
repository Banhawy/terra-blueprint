# -----------------------------------------------------------------------------
# ECS Fargate service
#
# One container per task, optional load balancer attachment, CPU target-tracking
# autoscaling, a deployment circuit breaker that rolls back failed deploys, and
# ECS Exec for shell access without SSH. Works for HTTP services (set
# container_port + target_group_arn) and for background workers (omit both).
# -----------------------------------------------------------------------------

data "aws_region" "current" {}

locals {
  create_cluster = var.cluster_arn == null
  cluster_arn    = local.create_cluster ? aws_ecs_cluster.this[0].arn : var.cluster_arn
  cluster_name   = local.create_cluster ? aws_ecs_cluster.this[0].name : element(split("/", var.cluster_arn), 1)
  autoscaling    = var.max_capacity > var.min_capacity
}

resource "aws_ecs_cluster" "this" {
  count = local.create_cluster ? 1 : 0
  name  = var.name

  setting {
    name  = "containerInsights"
    value = var.container_insights
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  count = local.create_cluster ? 1 : 0

  cluster_name       = aws_ecs_cluster.this[0].name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
}

module "logs" {
  source = "../cloudwatch/log-group"

  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_in_days
}

# --- IAM ---------------------------------------------------------------------
# Execution role: used by the ECS agent to pull the image, write logs and
# resolve `secrets` at task start. Task role: the identity the application
# code runs as -- callers attach their own policies to it (task_role_name).

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_secrets" {
  count = length(var.secret_arns) > 0 ? 1 : 0

  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = var.secret_arns
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  count = length(var.secret_arns) > 0 ? 1 : 0

  name   = "read-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets[0].json
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

# ECS Exec opens an SSM Session Manager channel from inside the task.
data "aws_iam_policy_document" "task_exec" {
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"] # these actions do not support resource-level permissions
  }
}

resource "aws_iam_role_policy" "task_exec" {
  count = var.enable_execute_command ? 1 : 0

  name   = "ecs-exec"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_exec.json
}

# --- Networking --------------------------------------------------------------

resource "aws_security_group" "this" {
  name        = "${var.name}-task"
  description = "ECS tasks of ${var.name}"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-task" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_allowed" {
  count = var.container_port == null ? 0 : length(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.this.id
  description                  = "Container port from an allowed source (e.g. the ALB)"
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = var.allowed_security_group_ids[count.index]
}

#trivy:ignore:AVD-AWS-0104 -- tasks reach AWS APIs, the database and third-party APIs; egress leaves via NAT.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- Task definition and service ---------------------------------------------

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    cpu_architecture        = var.cpu_architecture
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.image
      essential = true
      command   = var.command

      portMappings = var.container_port == null ? [] : [{
        containerPort = var.container_port
        protocol      = "tcp"
        appProtocol   = "http"
      }]

      environment = [for k, v in var.environment : { name = k, value = v }]
      secrets     = [for k, v in var.secrets : { name = k, valueFrom = v }]

      # Root filesystem is read-only; mount a volume or use /tmp-style paths
      # backed by ephemeral storage if the app needs to write.
      readonlyRootFilesystem = var.readonly_root_filesystem

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = module.logs.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = var.container_name
        }
      }
    }
  ])
}

resource "aws_ecs_service" "this" {
  name                   = var.name
  cluster                = local.cluster_arn
  task_definition        = aws_ecs_task_definition.this.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  enable_execute_command = var.enable_execute_command
  propagate_tags         = "SERVICE"

  health_check_grace_period_seconds = var.target_group_arn == null ? null : var.health_check_grace_period_seconds

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # A task definition that cannot become healthy (crash on boot, failing health
  # check) would otherwise leave the deployment IN_PROGRESS forever. The circuit
  # breaker marks it FAILED (emitting SERVICE_DEPLOYMENT_FAILED) and rolls back
  # to the last steady-state revision. Note: after a rollback, state still holds
  # the broken revision -- fix the image or config, then apply again.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn == null ? [] : [1]
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = false
  }

  lifecycle {
    # Autoscaling owns the running count once the service exists.
    ignore_changes = [desired_count]
  }
}

# --- Autoscaling -------------------------------------------------------------

resource "aws_appautoscaling_target" "this" {
  count = local.autoscaling ? 1 : 0

  service_namespace  = "ecs"
  resource_id        = "service/${local.cluster_name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
}

resource "aws_appautoscaling_policy" "cpu" {
  count = local.autoscaling ? 1 : 0

  name               = "${var.name}-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = var.cpu_target_utilization
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
