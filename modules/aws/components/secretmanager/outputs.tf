output "secret_arns" {
  value       = { for k, s in aws_secretsmanager_secret.this : k => s.arn }
  description = "Map of secret key to ARN. Pass these to ECS `secrets` or IAM policies."
}

output "secret_names" {
  value       = { for k, s in aws_secretsmanager_secret.this : k => s.name }
  description = "Map of secret key to full secret name."
}
