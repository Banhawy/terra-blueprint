# ---------------------------------------------------------------------------
# WAFv2 web ACL
# ---------------------------------------------------------------------------
# Edge-layer request filtering: volumetric rate limiting and AWS managed rule
# groups. This is deliberately the coarse half of rate limiting -- WAF keys on
# IP or a header and evaluates on a sliding window with up to ~30s of lag, so it
# stops floods before they cost compute, but it cannot express per-tenant or
# per-plan quotas. Those live in the application, which is the only layer that
# knows which org a request belongs to.
locals {
  # WAF requires log group names to start with this prefix and rejects the
  # PutLoggingConfiguration call outright otherwise.
  log_group_name = "aws-waf-logs-${var.name}"

  # A rate-based rule needs a scope-down statement only when it is restricted to
  # a host or a path. Precomputing which conditions each rule carries keeps the
  # dynamic blocks below readable: 0 conditions means no scope-down, 1 means the
  # condition sits directly under the statement, 2+ means it must be wrapped in
  # an `and_statement` (WAF has no implicit conjunction).
  rate_limit_rules = [
    for r in var.rate_limit_rules : merge(r, {
      condition_count = length(compact([
        try(r.host_header, null),
        try(r.path_prefix, null),
      ]))
    })
  ]
}

resource "aws_wafv2_web_acl" "this" {
  name  = var.name
  scope = var.scope

  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [1] : []
      content {}
    }

    dynamic "block" {
      for_each = var.default_action == "block" ? [1] : []
      content {}
    }
  }

  # -------------------------------------------------------------------------
  # AWS managed rule groups
  # -------------------------------------------------------------------------
  dynamic "rule" {
    for_each = { for g in var.managed_rule_groups : g.name => g }

    content {
      name     = rule.value.name
      priority = rule.value.priority

      # A managed group's own rules decide allow/block, so the ACL-level action
      # must be `override_action`, not `action` -- WAF rejects a rule that sets
      # both. `none` lets the group's verdicts stand; `count` demotes every
      # block inside it to an observation.
      override_action {
        dynamic "none" {
          for_each = rule.value.count_only ? [] : [1]
          content {}
        }

        dynamic "count" {
          for_each = rule.value.count_only ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = rule.value.vendor_name

          dynamic "rule_action_override" {
            for_each = rule.value.excluded_rules
            content {
              name = rule_action_override.value
              action_to_use {
                count {}
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = replace("${var.name}-${rule.value.name}", "/[^0-9A-Za-z_-]/", "-")
        sampled_requests_enabled   = true
      }
    }
  }

  # -------------------------------------------------------------------------
  # Rate-based rules
  # -------------------------------------------------------------------------
  dynamic "rule" {
    for_each = { for r in local.rate_limit_rules : r.name => r }

    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        dynamic "block" {
          for_each = rule.value.action == "block" ? [1] : []
          content {}
        }

        dynamic "count" {
          for_each = rule.value.action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        rate_based_statement {
          limit                 = rule.value.limit
          evaluation_window_sec = rule.value.window_seconds

          # IP and FORWARDED_IP are top-level aggregation keys; keying on a
          # header instead requires CUSTOM_KEYS with a custom_key block.
          aggregate_key_type = (
            rule.value.aggregate_on == "forwarded_ip" ? "FORWARDED_IP" :
            rule.value.aggregate_on == "custom_header" ? "CUSTOM_KEYS" : "IP"
          )

          # Required when aggregating on FORWARDED_IP: which XFF entry to trust
          # and what to do when the header is absent. FIRST is the client-most
          # entry, which is what CloudFront appends -- only use forwarded_ip
          # behind a proxy that overwrites the header, or a caller can spoof it
          # and mint a fresh bucket per request. MATCH on a missing header sends
          # such requests down the rule's action rather than letting them skip it.
          dynamic "forwarded_ip_config" {
            for_each = rule.value.aggregate_on == "forwarded_ip" ? [1] : []
            content {
              fallback_behavior = "MATCH"
              header_name       = "X-Forwarded-For"
            }
          }

          dynamic "custom_key" {
            for_each = rule.value.aggregate_on == "custom_header" ? [1] : []
            content {
              header {
                name = rule.value.header_name
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
          }

          # Scope-down: without one, the rule counts every request reaching the
          # ACL. With one, only matching requests are metered, so a per-host or
          # per-path limit can be far tighter than the global backstop.
          dynamic "scope_down_statement" {
            for_each = rule.value.condition_count > 0 ? [1] : []

            content {
              # Exactly one condition: it sits directly under the statement.
              dynamic "byte_match_statement" {
                for_each = (
                  rule.value.condition_count == 1 && try(rule.value.host_header, null) != null ? [1] : []
                )
                content {
                  positional_constraint = "EXACTLY"
                  search_string         = rule.value.host_header
                  field_to_match {
                    single_header {
                      name = "host"
                    }
                  }
                  text_transformation {
                    priority = 0
                    type     = "LOWERCASE"
                  }
                }
              }

              dynamic "byte_match_statement" {
                for_each = (
                  rule.value.condition_count == 1 && try(rule.value.path_prefix, null) != null ? [1] : []
                )
                content {
                  positional_constraint = "STARTS_WITH"
                  search_string         = rule.value.path_prefix
                  field_to_match {
                    uri_path {}
                  }
                  text_transformation {
                    priority = 0
                    type     = "LOWERCASE"
                  }
                }
              }

              # Both conditions: WAF needs them joined explicitly.
              dynamic "and_statement" {
                for_each = rule.value.condition_count > 1 ? [1] : []

                content {
                  statement {
                    byte_match_statement {
                      positional_constraint = "EXACTLY"
                      search_string         = rule.value.host_header
                      field_to_match {
                        single_header {
                          name = "host"
                        }
                      }
                      text_transformation {
                        priority = 0
                        type     = "LOWERCASE"
                      }
                    }
                  }

                  statement {
                    byte_match_statement {
                      positional_constraint = "STARTS_WITH"
                      search_string         = rule.value.path_prefix
                      field_to_match {
                        uri_path {}
                      }
                      text_transformation {
                        priority = 0
                        type     = "LOWERCASE"
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = replace("${var.name}-${rule.value.name}", "/[^0-9A-Za-z_-]/", "-")
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = replace(var.name, "/[^0-9A-Za-z_-]/", "-")
    sampled_requests_enabled   = true
  }
}

# ---------------------------------------------------------------------------
# Association
# ---------------------------------------------------------------------------
# count, not for_each. The ARNs handed in are usually ALB ARNs, and in a fresh
# environment the ALB does not exist yet at plan time -- `toset()` over them would
# be a set with unknown keys, which Terraform rejects ("Invalid for_each
# argument"). count only needs the list's *length* to be known, which it always is.
resource "aws_wafv2_web_acl_association" "this" {
  count = length(var.associated_resource_arns)

  resource_arn = var.associated_resource_arns[count.index]
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "waf" {
  count = var.logging_enabled ? 1 : 0

  name              = local.log_group_name
  retention_in_days = var.log_retention_in_days
}

# WAF writes to the log group with its own service-linked role, so no resource
# policy is needed here for CloudWatch Logs delivery.
resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.logging_enabled ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]

  dynamic "redacted_fields" {
    for_each = var.log_redacted_headers
    content {
      single_header {
        name = redacted_fields.value
      }
    }
  }

  # Without a filter WAF logs every request the ACL sees, which on a busy API is
  # a large bill for data nobody reads. Blocked and counted requests are the ones
  # that carry information.
  dynamic "logging_filter" {
    for_each = var.log_filter_blocked_only ? [1] : []

    content {
      default_behavior = "DROP"

      filter {
        behavior    = "KEEP"
        requirement = "MEETS_ANY"

        condition {
          action_condition {
            action = "BLOCK"
          }
        }

        condition {
          action_condition {
            action = "COUNT"
          }
        }
      }
    }
  }
}
