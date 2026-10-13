locals {
  web_acl_name = var.name

  default_visibility_config = {
    cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
    metric_name                = var.metric_name != null ? var.metric_name : var.name
    sampled_requests_enabled   = var.sampled_requests_enabled
  }
}

resource "aws_wafv2_web_acl" "this" {
  name        = local.web_acl_name
  description = var.description
  scope       = var.scope

  dynamic "default_action" {
    for_each = [lower(var.default_action)]

    content {
      dynamic "allow" {
        for_each = default_action.value == "allow" ? [1] : []
        content {}
      }

      dynamic "block" {
        for_each = default_action.value == "block" ? [1] : []
        content {}
      }
    }
  }

  dynamic "rule" {
    for_each = var.aws_managed_rule_groups

    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        dynamic "none" {
          for_each = lower(coalesce(try(rule.value.override_action, null), "none")) == "none" ? [1] : []
          content {}
        }

        dynamic "count" {
          for_each = lower(coalesce(try(rule.value.override_action, null), "none")) == "count" ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.managed_rule_group_name
          vendor_name = coalesce(try(rule.value.vendor_name, null), "AWS")
          version     = try(rule.value.version, null)

          dynamic "rule_action_override" {
            for_each = coalesce(try(rule.value.rule_action_overrides, null), [])

            content {
              name = rule_action_override.value.name

              action_to_use {
                dynamic "allow" {
                  for_each = lower(rule_action_override.value.action_to_use) == "allow" ? [1] : []
                  content {}
                }

                dynamic "block" {
                  for_each = lower(rule_action_override.value.action_to_use) == "block" ? [1] : []
                  content {}
                }

                dynamic "count" {
                  for_each = lower(rule_action_override.value.action_to_use) == "count" ? [1] : []
                  content {}
                }

                dynamic "captcha" {
                  for_each = lower(rule_action_override.value.action_to_use) == "captcha" ? [1] : []
                  content {}
                }

                dynamic "challenge" {
                  for_each = lower(rule_action_override.value.action_to_use) == "challenge" ? [1] : []
                  content {}
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = coalesce(
          try(rule.value.cloudwatch_metrics_enabled, null),
          var.cloudwatch_metrics_enabled
        )

        metric_name = coalesce(
          try(rule.value.metric_name, null),
          rule.value.name
        )

        sampled_requests_enabled = coalesce(
          try(rule.value.sampled_requests_enabled, null),
          var.sampled_requests_enabled
        )
      }
    }
  }

  dynamic "rule" {
    for_each = var.rate_based_rules

    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        dynamic "allow" {
          for_each = lower(rule.value.action) == "allow" ? [1] : []
          content {}
        }

        dynamic "block" {
          for_each = lower(rule.value.action) == "block" ? [1] : []
          content {}
        }

        dynamic "count" {
          for_each = lower(rule.value.action) == "count" ? [1] : []
          content {}
        }

        dynamic "captcha" {
          for_each = lower(rule.value.action) == "captcha" ? [1] : []
          content {}
        }

        dynamic "challenge" {
          for_each = lower(rule.value.action) == "challenge" ? [1] : []
          content {}
        }
      }

      statement {
        rate_based_statement {
          limit              = rule.value.limit
          aggregate_key_type = coalesce(try(rule.value.aggregate_key_type, null), "IP")
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = coalesce(
          try(rule.value.cloudwatch_metrics_enabled, null),
          var.cloudwatch_metrics_enabled
        )

        metric_name = coalesce(
          try(rule.value.metric_name, null),
          rule.value.name
        )

        sampled_requests_enabled = coalesce(
          try(rule.value.sampled_requests_enabled, null),
          var.sampled_requests_enabled
        )
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = local.default_visibility_config.cloudwatch_metrics_enabled
    metric_name                = local.default_visibility_config.metric_name
    sampled_requests_enabled   = local.default_visibility_config.sampled_requests_enabled
  }

  tags = merge(
    var.tags,
    {
      Name = local.web_acl_name
    }
  )
}

resource "aws_wafv2_web_acl_association" "this" {
  count = var.create_web_acl_association ? 1 : 0

  resource_arn = var.association_resource_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

resource "aws_cloudwatch_log_group" "waf" {
  count = var.enable_logging && var.create_log_group ? 1 : 0

  name              = var.log_group_name != null ? var.log_group_name : "aws-waf-logs-${var.name}"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.log_group_kms_key_id

  tags = merge(
    var.tags,
    {
      Name = var.log_group_name != null ? var.log_group_name : "aws-waf-logs-${var.name}"
    }
  )
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.enable_logging ? 1 : 0

  resource_arn = aws_wafv2_web_acl.this.arn

  log_destination_configs = [
    var.create_log_group ? aws_cloudwatch_log_group.waf[0].arn : var.existing_log_destination_arn
  ]

  dynamic "redacted_fields" {
    for_each = var.redacted_single_header_fields

    content {
      single_header {
        name = redacted_fields.value
      }
    }
  }

  depends_on = [
    aws_wafv2_web_acl.this,
    aws_cloudwatch_log_group.waf
  ]
}