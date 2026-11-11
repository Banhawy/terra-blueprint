variable "name" {
  type        = string
  description = "Service name and prefix for its resources, e.g. acme-staging-web-api."
}

variable "cluster_arn" {
  type        = string
  description = "Existing ECS cluster to run in. Null creates a dedicated cluster named after the service."
  default     = null
}

variable "container_insights" {
  type        = string
  description = "Container Insights for a created cluster: enabled, enhanced or disabled."
  default     = "enabled"
}

variable "vpc_id" {
  type        = string
  description = "VPC for the task security group."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnets the tasks run in."
}

variable "image" {
  type        = string
  description = "Full image reference, e.g. 111111111111.dkr.ecr.eu-central-1.amazonaws.com/acme/web-api:1.4.2."
}

variable "container_name" {
  type        = string
  description = "Name of the container inside the task."
  default     = "app"
}

variable "command" {
  type        = list(string)
  description = "Override the image's CMD. Null keeps the image default."
  default     = null
}

variable "container_port" {
  type        = number
  description = "Port the container listens on. Null for workers that serve no traffic."
  default     = null
}

variable "cpu" {
  type        = number
  description = "Task CPU units (256 = 0.25 vCPU)."
  default     = 512
}

variable "memory" {
  type        = number
  description = "Task memory in MiB; must be a valid pairing with cpu."
  default     = 1024
}

variable "cpu_architecture" {
  type        = string
  description = "X86_64 or ARM64 (Graviton -- ~20% cheaper; needs an arm64 image)."
  default     = "X86_64"
}

variable "environment" {
  type        = map(string)
  description = "Plain environment variables. Never put secrets here -- use `secrets`."
  default     = {}
}

variable "secrets" {
  type        = map(string)
  description = "Environment variable name -> Secrets Manager ARN (optionally with :json-key:: suffix). Resolved by ECS at task start."
  default     = {}
}

variable "secret_arns" {
  type        = list(string)
  description = "Secret ARNs (without JSON-key suffixes) the execution role may read -- every secret referenced in `secrets`."
  default     = []
}

variable "readonly_root_filesystem" {
  type        = bool
  description = "Mount the container's root filesystem read-only."
  default     = false
}

variable "desired_count" {
  type        = number
  description = "Initial task count. Autoscaling takes over after creation."
  default     = 1
}

variable "min_capacity" {
  type        = number
  description = "Autoscaling floor."
  default     = 1
}

variable "max_capacity" {
  type        = number
  description = "Autoscaling ceiling. Equal to min_capacity disables autoscaling."
  default     = 1
}

variable "cpu_target_utilization" {
  type        = number
  description = "Average CPU % that target tracking aims for."
  default     = 70
}

variable "target_group_arn" {
  type        = string
  description = "ALB target group to register tasks in. Null for services without a load balancer."
  default     = null
}

variable "health_check_grace_period_seconds" {
  type        = number
  description = "Seconds the ALB health check is ignored after a task starts -- cover your app's cold start (migrations, warm-up)."
  default     = 60
}

variable "allowed_security_group_ids" {
  type        = list(string)
  description = "Security groups allowed to reach container_port (typically the ALB's)."
  default     = []
}

variable "enable_execute_command" {
  type        = bool
  description = "Allow `aws ecs execute-command` shells into running tasks."
  default     = true
}

variable "log_retention_in_days" {
  type        = number
  description = "Container log retention."
  default     = 30
}
