output "alarm_arns" {
  value       = { for k, a in aws_cloudwatch_metric_alarm.this : k => a.arn }
  description = "Map of alarm key to alarm ARN."
}
