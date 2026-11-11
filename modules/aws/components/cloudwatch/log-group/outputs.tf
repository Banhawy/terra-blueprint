output "name" {
  value       = aws_cloudwatch_log_group.this.name
  description = "Log group name."
}

output "arn" {
  value       = aws_cloudwatch_log_group.this.arn
  description = "Log group ARN."
}
