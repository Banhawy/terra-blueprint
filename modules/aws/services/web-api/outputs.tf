output "url" {
  value       = "https://${var.hostname}"
  description = "Public URL of the API."
}

output "hostname" {
  value       = var.hostname
  description = "Public hostname of the API (e.g. the origin for a CloudFront /api/* proxy)."
}

output "dns_records" {
  value = var.route53_zone_id != null ? [] : [{
    name  = var.hostname
    type  = "CNAME"
    value = module.alb.dns_name
  }]
  description = "Records to create at your DNS provider (empty when Route 53 manages them)."
}

output "alb_dns_name" {
  value       = module.alb.dns_name
  description = "Load balancer DNS name; also the origin for a CloudFront /api/* proxy."
}

output "cluster_name" {
  value       = module.app.cluster_name
  description = "ECS cluster."
}

output "service_name" {
  value       = module.app.service_name
  description = "ECS service (for `aws ecs execute-command` and deploy scripts)."
}

output "task_role_arn" {
  value       = module.app.task_role_arn
  description = "Role the application runs as."
}

output "database_endpoint" {
  value       = module.database.cluster_endpoint
  description = "Aurora writer endpoint."
}

output "database_master_secret_arn" {
  value       = module.database.master_user_secret_arn
  description = "RDS-managed master credentials (for admin tasks like creating the IAM-auth user)."
}

output "cache_endpoint" {
  value       = module.cache.primary_endpoint
  description = "Valkey primary endpoint (TLS)."
}

output "uploads_bucket" {
  value       = module.uploads.bucket_name
  description = "Uploads bucket."
}

output "app_secret_arns" {
  value       = module.secrets.secret_arns
  description = "Secrets whose values must be set before the app can start."
}

output "alerts_topic_arn" {
  value       = aws_sns_topic.alerts.arn
  description = "SNS topic receiving all alarms; subscribe more targets here."
}

output "alert_webhook_secret_arn" {
  value       = try(module.notifier_secret[0].secret_arns["webhook-url"], null)
  description = "Secret to put the chat webhook URL in."
}
