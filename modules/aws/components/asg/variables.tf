variable "name" {
  type        = string
  description = "Name of the group and prefix for its resources."
}

variable "vpc_id" {
  type        = string
  description = "VPC for the instance security group."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnets to launch instances in."
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type."
  default     = "t3.small"
}

variable "ami_ssm_parameter" {
  type        = string
  description = "SSM parameter holding the AMI ID. Use the arm64 parameter together with a Graviton instance type."
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

variable "user_data" {
  type        = string
  description = "Rendered (not base64) user-data script; gzip+base64 encoding is done here."
  default     = null
}

variable "root_volume_size" {
  type        = number
  description = "Root volume size in GiB."
  default     = 20
}

variable "kms_key_arn" {
  type        = string
  description = "Optional customer-managed KMS key for the root volume."
  default     = null
}

variable "detailed_monitoring" {
  type        = bool
  description = "1-minute EC2 metrics (extra cost)."
  default     = false
}

variable "additional_policy_arns" {
  type        = list(string)
  description = "Extra managed policies for the instance role. For inline permissions, attach to the output role_name."
  default     = []
}

variable "min_size" {
  type        = number
  description = "Minimum instances. 0 lets the group scale to zero when idle."
  default     = 0
}

variable "max_size" {
  type        = number
  description = "Maximum instances."
  default     = 2
}

variable "scale_out_step" {
  type        = number
  description = "Instances added each time the scale-out policy fires."
  default     = 1
}

variable "scaling_cooldown_seconds" {
  type        = number
  description = "Seconds between scaling activities."
  default     = 300
}

variable "instance_refresh_min_healthy_percentage" {
  type        = number
  description = "Share of capacity kept in service while instances are replaced."
  default     = 50
}
