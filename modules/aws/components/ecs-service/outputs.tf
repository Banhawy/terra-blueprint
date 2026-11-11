output "cluster_arn" {
  value       = local.cluster_arn
  description = "Cluster the service runs in."
}

output "cluster_name" {
  value       = local.cluster_name
  description = "Cluster name (ClusterName CloudWatch dimension)."
}

output "service_name" {
  value       = aws_ecs_service.this.name
  description = "Service name (ServiceName CloudWatch dimension)."
}

output "service_arn" {
  value       = aws_ecs_service.this.id
  description = "Service ARN."
}

output "task_definition_arn" {
  value       = aws_ecs_task_definition.this.arn
  description = "Current task definition revision."
}

output "task_definition_family" {
  value       = aws_ecs_task_definition.this.family
  description = "Task definition family."
}

output "task_role_arn" {
  value       = aws_iam_role.task.arn
  description = "Role the application runs as."
}

output "task_role_name" {
  value       = aws_iam_role.task.name
  description = "Name of the task role -- attach application permissions to it."
}

output "execution_role_arn" {
  value       = aws_iam_role.execution.arn
  description = "Execution role (image pull, logs, secrets)."
}

output "security_group_id" {
  value       = aws_security_group.this.id
  description = "Task security group -- allow it on databases and caches."
}

output "log_group_name" {
  value       = module.logs.name
  description = "Container log group."
}
