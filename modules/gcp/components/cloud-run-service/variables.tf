variable "name" {
  type        = string
  description = "Service name."
}

variable "region" {
  type        = string
  description = "Region to run in."
}

variable "image" {
  type        = string
  description = "Full image reference, e.g. europe-west1-docker.pkg.dev/acme-staging/acme-staging/web-api:1.0.0."
}

variable "service_account_email" {
  type        = string
  description = "Runtime service account. Create one per service; never use the default compute account."
}

variable "container_port" {
  type        = number
  description = "Port the container listens on (Cloud Run also sets PORT)."
  default     = 8080
}

variable "cpu" {
  type        = string
  description = "CPU limit, e.g. \"1\"."
  default     = "1"
}

variable "memory" {
  type        = string
  description = "Memory limit, e.g. \"512Mi\"."
  default     = "512Mi"
}

variable "concurrency" {
  type        = number
  description = "Concurrent requests per instance."
  default     = 80
}

variable "request_timeout_seconds" {
  type        = number
  description = "Request timeout."
  default     = 60
}

variable "min_instances" {
  type        = number
  description = "Warm instances kept running (0 = scale to zero, with cold starts)."
  default     = 0
}

variable "max_instances" {
  type        = number
  description = "Upper bound on instances -- also caps how hard the service can hit the database."
  default     = 3
}

variable "environment" {
  type        = map(string)
  description = "Plain environment variables."
  default     = {}
}

variable "secrets" {
  type        = map(string)
  description = "Environment variable name -> Secret Manager secret ID (latest version is used)."
  default     = {}
}

variable "subnet_id" {
  type        = string
  description = "Subnet for Direct VPC egress. Null = no VPC access."
  default     = null
}

variable "health_check_path" {
  type        = string
  description = "HTTP path for startup and liveness probes."
  default     = "/healthz"
}

variable "ingress" {
  type        = string
  description = "INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY or INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER (behind an HTTPS load balancer)."
  default     = "INGRESS_TRAFFIC_ALL"
}

variable "allow_unauthenticated" {
  type        = bool
  description = "Let anyone invoke the service (a public API). false requires Google-signed identity tokens."
  default     = false
}

variable "deletion_protection" {
  type        = bool
  description = "Block terraform destroy of the service."
  default     = false
}
