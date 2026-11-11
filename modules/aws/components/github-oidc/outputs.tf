output "oidc_provider_arn" {
  value       = local.oidc_provider_arn
  description = "GitHub OIDC provider ARN -- pass to other instances of this module."
}

output "role_arns" {
  value       = { for k, r in aws_iam_role.this : k => r.arn }
  description = "Map of role key to ARN. Store these as GitHub repository/environment variables."
}
