# -----------------------------------------------------------------------------
# Lambda function
#
# Code comes either from a local directory (zipped here with archive_file --
# the simple case, used by the alert notifier) or from an object in S3 built by
# a separate pipeline. VPC attachment, EFS, an S3 trigger and a function URL
# are all optional and only rendered when configured.
# -----------------------------------------------------------------------------

locals {
  from_source_dir = var.source_dir != null
  in_vpc          = length(var.vpc_subnet_ids) > 0
}

data "archive_file" "this" {
  count = local.from_source_dir ? 1 : 0

  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.root}/.build/${var.function_name}.zip"
  excludes    = ["__pycache__", "tests", "*.pyc"]
}

module "logs" {
  source = "../cloudwatch/log-group"

  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_in_days
}

# --- IAM ---------------------------------------------------------------------

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
  name               = var.function_name
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

# Write logs only to this function's own log group.
data "aws_iam_policy_document" "logs" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${module.logs.arn}:*"]
  }
}

resource "aws_iam_role_policy" "logs" {
  name   = "logs"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.logs.json
}

resource "aws_iam_role_policy_attachment" "vpc" {
  count = local.in_vpc ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# for_each over the map *keys* (always known at plan time), so policy JSON that
# is only computed during apply is fine.
resource "aws_iam_role_policy" "extra" {
  for_each = var.policies

  name   = each.key
  role   = aws_iam_role.this.id
  policy = each.value
}

# --- Function ----------------------------------------------------------------

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  description   = var.description
  role          = aws_iam_role.this.arn
  runtime       = var.runtime
  handler       = var.handler
  architectures = var.architectures
  timeout       = var.timeout
  memory_size   = var.memory_size

  filename         = local.from_source_dir ? data.archive_file.this[0].output_path : null
  source_code_hash = local.from_source_dir ? data.archive_file.this[0].output_base64sha256 : null
  s3_bucket        = local.from_source_dir ? null : var.s3_bucket
  s3_key           = local.from_source_dir ? null : var.s3_key

  reserved_concurrent_executions = var.reserved_concurrent_executions

  logging_config {
    log_format = "JSON"
    log_group  = module.logs.name
  }

  tracing_config {
    mode = var.tracing_mode
  }

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  dynamic "vpc_config" {
    for_each = local.in_vpc ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  dynamic "file_system_config" {
    for_each = var.efs_access_point_arn == null ? [] : [1]
    content {
      arn              = var.efs_access_point_arn
      local_mount_path = var.efs_mount_path
    }
  }

  depends_on = [aws_iam_role_policy.logs]
}

# --- Optional triggers -------------------------------------------------------

resource "aws_lambda_permission" "s3" {
  count = var.s3_trigger == null ? 0 : 1

  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.s3_trigger.bucket_arn
}

resource "aws_s3_bucket_notification" "this" {
  count  = var.s3_trigger == null ? 0 : 1
  bucket = var.s3_trigger.bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.this.arn
    events              = var.s3_trigger.events
    filter_prefix       = var.s3_trigger.prefix
  }

  depends_on = [aws_lambda_permission.s3]
}

resource "aws_lambda_function_url" "this" {
  count = var.function_url == null ? 0 : 1

  function_name      = aws_lambda_function.this.function_name
  authorization_type = var.function_url.authorization_type

  cors {
    allow_origins = var.function_url.allow_origins
    allow_methods = var.function_url.allow_methods
  }
}
