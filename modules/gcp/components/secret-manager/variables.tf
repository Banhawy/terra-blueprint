variable "name_prefix" {
  type        = string
  description = "Prefix for secret IDs; secrets become <prefix>-<key>."
}

variable "secrets" {
  description = "Secrets to create, keyed by short name."
  type = map(object({
    description = string
  }))
  default = {}
}
