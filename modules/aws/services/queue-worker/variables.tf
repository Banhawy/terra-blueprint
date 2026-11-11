variable "name" {
  type        = string
  description = "Worker name and prefix for its resources, e.g. acme-staging-queue-worker."
}

variable "vpc_id" {
  type        = string
  description = "VPC for the worker instances."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnets for the worker instances (they need NAT or VPC endpoints to reach AWS APIs)."
}

variable "instance_type" {
  type        = string
  description = "Worker instance type."
  default     = "t3.small"
}

variable "max_instances" {
  type        = number
  description = "Upper bound on concurrent workers (one job per worker at a time)."
  default     = 2
}

variable "scale_out_backlog" {
  type        = number
  description = "Visible messages that trigger adding a worker."
  default     = 1
}

variable "job_timeout_seconds" {
  type        = number
  description = "Longest a single job may take. Becomes the queue's visibility timeout and the worker's graceful-stop timeout."
  default     = 900
}

variable "max_receive_count" {
  type        = number
  description = "Attempts before a message is moved to the dead-letter queue."
  default     = 3
}

variable "message_retention_seconds" {
  type        = number
  description = "How long unprocessed jobs stay in the queue."
  default     = 345600 # 4 days
}

variable "results_retention_days" {
  type        = number
  description = "Days results are kept in the results bucket."
  default     = 30
}

variable "log_retention_in_days" {
  type        = number
  description = "Worker log retention."
  default     = 30
}

variable "alarm_topic_arn" {
  type        = string
  description = "SNS topic for operational alarms (DLQ, backlog age, CPU) -- e.g. web-api's alerts topic. Null = alarms without notifications."
  default     = null
}

variable "alarm_oldest_message_age_seconds" {
  type        = number
  description = "Alarm when the oldest waiting job is older than this."
  default     = 1800
}

variable "force_destroy" {
  type        = bool
  description = "Allow destroying the results bucket while it holds results."
  default     = false
}
