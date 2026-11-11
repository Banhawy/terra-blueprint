output "queue_url" {
  value       = aws_sqs_queue.jobs.url
  description = "Send jobs here (JSON message bodies)."
}

output "queue_arn" {
  value       = aws_sqs_queue.jobs.arn
  description = "Job queue ARN."
}

output "dlq_url" {
  value       = aws_sqs_queue.dlq.url
  description = "Dead-letter queue. Redrive with `aws sqs start-message-move-task --source-arn <dlq arn>`."
}

output "results_bucket" {
  value       = module.results.bucket_name
  description = "Bucket the worker writes results/<message id>.json to."
}

output "asg_name" {
  value       = module.workers.asg_name
  description = "Auto Scaling group running the workers."
}

output "producer_policy_json" {
  value       = data.aws_iam_policy_document.producer.json
  description = "IAM policy granting enqueue + result read. Attach it to whatever produces jobs."
}
