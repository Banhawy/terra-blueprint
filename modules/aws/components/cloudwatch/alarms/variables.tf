variable "name_prefix" {
  type        = string
  description = "Prefix for every alarm name; the map key is appended, e.g. acme-staging-web-api-alb-5xx."
}

variable "alarms" {
  description = <<-EOT
    Alarms to create, keyed by a short name. Each entry mirrors the arguments of
    aws_cloudwatch_metric_alarm. Set extended_statistic (e.g. "p99") instead of
    statistic for percentiles. alarm_actions / ok_actions override the defaults
    for one alarm -- e.g. to point a scaling alarm at an Auto Scaling policy.
  EOT
  type = map(object({
    description         = string
    namespace           = string
    metric_name         = string
    dimensions          = map(string)
    threshold           = number
    comparison_operator = string
    statistic           = optional(string, "Average")
    extended_statistic  = optional(string)
    period              = optional(number, 300)
    evaluation_periods  = optional(number, 1)
    datapoints_to_alarm = optional(number)
    treat_missing_data  = optional(string, "notBreaching")
    unit                = optional(string)
    alarm_actions       = optional(list(string))
    ok_actions          = optional(list(string))
  }))
  default = {}
}

variable "default_alarm_actions" {
  type        = list(string)
  description = "ARNs notified when any alarm without its own alarm_actions fires -- typically one SNS topic."
  default     = []
}

variable "default_ok_actions" {
  type        = list(string)
  description = "ARNs notified when an alarm without its own ok_actions recovers."
  default     = []
}
