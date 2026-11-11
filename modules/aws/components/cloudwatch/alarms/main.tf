# One module call creates a whole set of related alarms from a map, so a
# service declares its alarms as data instead of repeating resource blocks.
resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = var.alarms

  alarm_name          = "${var.name_prefix}-${each.key}"
  alarm_description   = each.value.description
  namespace           = each.value.namespace
  metric_name         = each.value.metric_name
  dimensions          = each.value.dimensions
  statistic           = each.value.extended_statistic == null ? each.value.statistic : null
  extended_statistic  = each.value.extended_statistic
  period              = each.value.period
  evaluation_periods  = each.value.evaluation_periods
  datapoints_to_alarm = each.value.datapoints_to_alarm
  threshold           = each.value.threshold
  comparison_operator = each.value.comparison_operator
  treat_missing_data  = each.value.treat_missing_data
  unit                = each.value.unit

  # Per-alarm actions win; otherwise every alarm notifies the shared targets.
  alarm_actions = each.value.alarm_actions != null ? each.value.alarm_actions : var.default_alarm_actions
  ok_actions    = each.value.ok_actions != null ? each.value.ok_actions : var.default_ok_actions
}
