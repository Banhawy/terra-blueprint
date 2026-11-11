# What the worker instances may do, beyond SSM and CloudWatch agent access
# granted by the asg component.

data "aws_iam_policy_document" "worker" {
  statement {
    sid = "ConsumeJobs"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueAttributes",
    ]
    resources = [aws_sqs_queue.jobs.arn]
  }

  statement {
    sid       = "ReadCode"
    actions   = ["s3:GetObject"]
    resources = ["${module.code.bucket_arn}/*"]
  }

  statement {
    sid       = "WriteResults"
    actions   = ["s3:PutObject"]
    resources = ["${module.results.bucket_arn}/*"]
  }

  statement {
    sid       = "ProtectWhileBusy"
    actions   = ["autoscaling:SetInstanceProtection"]
    resources = [module.workers.asg_arn]
  }
}

resource "aws_iam_role_policy" "worker" {
  name   = "worker"
  role   = module.workers.role_name
  policy = data.aws_iam_policy_document.worker.json
}

# Ready-made policy for whatever enqueues jobs (e.g. the web-api task role).
data "aws_iam_policy_document" "producer" {
  statement {
    actions   = ["sqs:SendMessage", "sqs:GetQueueUrl"]
    resources = [aws_sqs_queue.jobs.arn]
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["${module.results.bucket_arn}/*"]
  }
}
