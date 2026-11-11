variable "function_name" {
  type        = string
  description = "Function name; also names its role and log group."
}

variable "description" {
  type        = string
  description = "What the function does."
  default     = null
}

variable "runtime" {
  type        = string
  description = "Lambda runtime."
  default     = "python3.12"
}

variable "handler" {
  type        = string
  description = "Entry point, e.g. handler.lambda_handler."
  default     = "handler.lambda_handler"
}

variable "architectures" {
  type        = list(string)
  description = "[\"arm64\"] (Graviton, cheaper) or [\"x86_64\"]."
  default     = ["arm64"]
}

variable "timeout" {
  type        = number
  description = "Seconds before the invocation is killed."
  default     = 30
}

variable "memory_size" {
  type        = number
  description = "Memory in MB (CPU scales with it)."
  default     = 256
}

variable "source_dir" {
  type        = string
  description = "Local directory to zip and deploy. Mutually exclusive with s3_bucket/s3_key."
  default     = null
}

variable "s3_bucket" {
  type        = string
  description = "Bucket holding a pre-built deployment package."
  default     = null
}

variable "s3_key" {
  type        = string
  description = "Key of the pre-built deployment package."
  default     = null
}

variable "environment_variables" {
  type        = map(string)
  description = "Environment variables. Pass secret *ARNs*, not secret values."
  default     = {}
}

variable "policies" {
  type        = map(string)
  description = "Inline IAM policies (name -> policy JSON) granting the function what it needs beyond logging."
  default     = {}
}

variable "reserved_concurrent_executions" {
  type        = number
  description = "Cap on concurrent executions. -1 = unreserved."
  default     = -1
}

variable "tracing_mode" {
  type        = string
  description = "X-Ray tracing: PassThrough or Active."
  default     = "PassThrough"
}

variable "log_retention_in_days" {
  type        = number
  description = "Function log retention."
  default     = 30
}

variable "vpc_subnet_ids" {
  type        = list(string)
  description = "Private subnets to attach the function to. Empty = no VPC (it then cannot reach private resources)."
  default     = []
}

variable "vpc_security_group_ids" {
  type        = list(string)
  description = "Security groups for a VPC-attached function."
  default     = []
}

variable "efs_access_point_arn" {
  type        = string
  description = "Optional EFS access point to mount (requires VPC attachment)."
  default     = null
}

variable "efs_mount_path" {
  type        = string
  description = "Mount path for EFS; must start with /mnt/."
  default     = "/mnt/efs"
}

variable "s3_trigger" {
  description = "Invoke the function on S3 events from one bucket."
  type = object({
    bucket_id  = string
    bucket_arn = string
    events     = optional(list(string), ["s3:ObjectCreated:*"])
    prefix     = optional(string)
  })
  default = null
}

variable "function_url" {
  description = "Expose an HTTPS endpoint. Keep authorization_type = AWS_IAM unless the function authenticates callers itself."
  type = object({
    authorization_type = optional(string, "AWS_IAM")
    allow_origins      = optional(list(string), [])
    allow_methods      = optional(list(string), ["POST"])
  })
  default = null
}
