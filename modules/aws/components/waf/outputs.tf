output "web_acl_arn" {
  value       = aws_wafv2_web_acl.this.arn
  description = "ARN of the web ACL. CloudFront distributions reference this directly; REGIONAL resources are associated by this module."
}

output "web_acl_id" {
  value       = aws_wafv2_web_acl.this.id
  description = "ID of the web ACL."
}

output "web_acl_name" {
  value       = aws_wafv2_web_acl.this.name
  description = "Name of the web ACL, which is also its top-level CloudWatch metric name."
}

output "log_group_name" {
  value       = try(aws_cloudwatch_log_group.waf[0].name, null)
  description = "CloudWatch log group receiving WAF logs, or null when logging is disabled."
}
