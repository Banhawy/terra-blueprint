output "repository_urls" {
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
  description = "Map of repository name to URL (<account>.dkr.ecr.<region>.amazonaws.com/<name>)."
}

output "repository_arns" {
  value       = { for k, r in aws_ecr_repository.this : k => r.arn }
  description = "Map of repository name to ARN, for scoping CI push permissions."
}
