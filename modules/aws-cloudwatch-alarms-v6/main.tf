# Reusable CloudWatch alarms module.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.64.0"
    }
  }
}

locals {
  alarm_name_prefix = var.alarm_name_prefix != null ? "${var.alarm_name_prefix}-" : ""
}

# Log Metric Filters
resource "aws_cloudwatch_log_metric_filter" "this" {
  for_each = var.log_metric_filters

  name           = coalesce(each.value.name, "${local.alarm_name_prefix}${each.key}")
  log_group_name = each.value.log_group_name
  pattern        = each.value.pattern

  metric_transformation {
    name          = each.value.metric_name
    namespace     = each.value.metric_namespace
    value         = each.value.metric_value
    default_value = each.value.default_value
    dimensions    = each.value.dimensions
    unit          = each.value.unit
  }
}

# Metric Alarms
resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = var.metric_alarms

  alarm_name          = coalesce(each.value.alarm_name, "${local.alarm_name_prefix}${each.key}")
  alarm_description   = each.value.alarm_description
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = each.value.evaluation_periods
  datapoints_to_alarm = each.value.datapoints_to_alarm
  evaluation_interval = each.value.evaluation_interval
  threshold           = each.value.threshold
  threshold_metric_id = each.value.threshold_metric_id
  treat_missing_data  = coalesce(each.value.treat_missing_data, var.default_treat_missing_data)

  namespace          = each.value.namespace
  metric_name        = each.value.metric_name
  dimensions         = each.value.dimensions
  period             = each.value.period
  statistic          = each.value.statistic
  extended_statistic = each.value.extended_statistic
  unit               = each.value.unit

  evaluate_low_sample_count_percentiles = each.value.evaluate_low_sample_count_percentiles

  actions_enabled           = coalesce(each.value.actions_enabled, var.actions_enabled)
  alarm_actions             = coalesce(each.value.alarm_actions, var.default_alarm_actions)
  ok_actions                = coalesce(each.value.ok_actions, var.default_ok_actions)
  insufficient_data_actions = coalesce(each.value.insufficient_data_actions, var.default_insufficient_data_actions)

  dynamic "metric_query" {
    for_each = each.value.metric_queries

    content {
      id          = metric_query.value.id
      account_id  = metric_query.value.account_id
      expression  = metric_query.value.expression
      label       = metric_query.value.label
      period      = metric_query.value.period
      return_data = metric_query.value.return_data

      dynamic "metric" {
        for_each = metric_query.value.metric != null ? [metric_query.value.metric] : []

        content {
          namespace   = metric.value.namespace
          metric_name = metric.value.metric_name
          dimensions  = metric.value.dimensions
          period      = metric.value.period
          stat        = metric.value.stat
          unit        = metric.value.unit
        }
      }
    }
  }

  dynamic "evaluation_criteria" {
    for_each = each.value.promql_criteria != null ? [each.value.promql_criteria] : []

    content {
      promql_criteria {
        query           = evaluation_criteria.value.query
        pending_period  = evaluation_criteria.value.pending_period
        recovery_period = evaluation_criteria.value.recovery_period
      }
    }
  }

  dynamic "warm_up_configuration" {
    for_each = each.value.warm_up_configuration != null ? [each.value.warm_up_configuration] : []

    content {
      warm_up_period_duration_in_minutes              = warm_up_configuration.value.warm_up_period_duration_in_minutes
      only_start_evaluating_after_warm_up_period_ends = warm_up_configuration.value.only_start_evaluating_after_warm_up_period_ends
    }
  }

  tags = merge(
    var.tags,
    each.value.tags,
    { Name = coalesce(each.value.alarm_name, "${local.alarm_name_prefix}${each.key}") }
  )

  depends_on = [aws_cloudwatch_log_metric_filter.this]
}

# Composite Alarms
resource "aws_cloudwatch_composite_alarm" "this" {
  for_each = var.composite_alarms

  alarm_name                = coalesce(each.value.alarm_name, "${local.alarm_name_prefix}${each.key}")
  alarm_description         = each.value.alarm_description
  alarm_rule                = each.value.alarm_rule
  actions_enabled           = coalesce(each.value.actions_enabled, var.actions_enabled)
  alarm_actions             = coalesce(each.value.alarm_actions, var.default_alarm_actions)
  ok_actions                = coalesce(each.value.ok_actions, var.default_ok_actions)
  insufficient_data_actions = coalesce(each.value.insufficient_data_actions, var.default_insufficient_data_actions)

  dynamic "actions_suppressor" {
    for_each = each.value.actions_suppressor != null ? [each.value.actions_suppressor] : []

    content {
      alarm            = actions_suppressor.value.alarm
      extension_period = actions_suppressor.value.extension_period
      wait_period      = actions_suppressor.value.wait_period
    }
  }

  tags = merge(
    var.tags,
    each.value.tags,
    { Name = coalesce(each.value.alarm_name, "${local.alarm_name_prefix}${each.key}") }
  )

  depends_on = [aws_cloudwatch_metric_alarm.this]
}
