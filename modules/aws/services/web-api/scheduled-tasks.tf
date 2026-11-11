# -----------------------------------------------------------------------------
# Scheduled tasks: one-off runs of the service's image on a schedule, e.g.
# nightly cleanups or report generation. Each entry in var.scheduled_tasks
# becomes an EventBridge Scheduler schedule that starts a Fargate task with a
# command override, using the service's task definition, network and roles.
# -----------------------------------------------------------------------------

locals {
  scheduled_tasks = { for k, t in var.scheduled_tasks : k => t if t.enabled }
}

data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  count = length(local.scheduled_tasks) > 0 ? 1 : 0

  name               = "${var.name}-scheduler"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json
}

data "aws_iam_policy_document" "scheduler" {
  statement {
    sid     = "RunTask"
    actions = ["ecs:RunTask"]
    # Any revision of this service's task definition family.
    resources = ["arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:task-definition/${module.app.task_definition_family}:*"]
    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [module.app.cluster_arn]
    }
  }

  statement {
    sid       = "PassTaskRoles"
    actions   = ["iam:PassRole"]
    resources = [module.app.execution_role_arn, module.app.task_role_arn]
  }
}

resource "aws_iam_role_policy" "scheduler" {
  count = length(local.scheduled_tasks) > 0 ? 1 : 0

  name   = "run-scheduled-tasks"
  role   = aws_iam_role.scheduler[0].id
  policy = data.aws_iam_policy_document.scheduler.json
}

resource "aws_scheduler_schedule" "task" {
  for_each = local.scheduled_tasks

  name                         = "${var.name}-${each.key}"
  description                  = each.value.description
  schedule_expression          = each.value.schedule_expression
  schedule_expression_timezone = each.value.timezone

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = module.app.cluster_arn
    role_arn = aws_iam_role.scheduler[0].arn

    ecs_parameters {
      task_definition_arn = module.app.task_definition_arn
      launch_type         = "FARGATE"

      network_configuration {
        subnets          = var.private_subnet_ids
        security_groups  = [module.app.security_group_id]
        assign_public_ip = false
      }
    }

    input = jsonencode({
      containerOverrides = [{
        name    = "app"
        command = each.value.command
      }]
    })

    retry_policy {
      maximum_retry_attempts = 0 # a scheduled job should not silently run twice
    }
  }
}
