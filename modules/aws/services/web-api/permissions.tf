# Application permissions, attached to the task role the containers run as.

data "aws_iam_policy_document" "app" {
  statement {
    sid       = "UploadsBucketObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${module.uploads.bucket_arn}/*"]
  }

  statement {
    sid       = "UploadsBucketList"
    actions   = ["s3:ListBucket"]
    resources = [module.uploads.bucket_arn]
  }

  dynamic "statement" {
    for_each = var.db_use_iam_auth ? [1] : []
    content {
      sid     = "DatabaseIamAuth"
      actions = ["rds-db:connect"]
      resources = [
        "arn:aws:rds-db:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:dbuser:${module.database.cluster_resource_id}/${var.db_app_username}",
      ]
    }
  }
}

resource "aws_iam_role_policy" "app" {
  name   = "app"
  role   = module.app.task_role_name
  policy = data.aws_iam_policy_document.app.json
}
