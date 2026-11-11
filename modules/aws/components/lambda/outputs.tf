output "function_name" {
  value       = aws_lambda_function.this.function_name
  description = "Function name."
}

output "function_arn" {
  value       = aws_lambda_function.this.arn
  description = "Function ARN (for permissions and event subscriptions)."
}

output "role_name" {
  value       = aws_iam_role.this.name
  description = "Execution role name."
}

output "function_url" {
  value       = try(aws_lambda_function_url.this[0].function_url, null)
  description = "Function URL, when enabled."
}

output "log_group_name" {
  value       = module.logs.name
  description = "Function log group."
}
