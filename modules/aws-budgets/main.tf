resource "aws_budgets_budget" "this" {
  for_each = var.budgets

  name         = coalesce(each.value.name, each.key)
  budget_type  = each.value.budget_type
  limit_amount = each.value.limit_amount
  limit_unit   = each.value.limit_unit

  time_unit         = each.value.time_unit
  time_period_start = each.value.time_period_start
  time_period_end   = each.value.time_period_end

  # Narrow the budget to specific services, accounts, regions or tags.
  dynamic "cost_filter" {
    for_each = each.value.cost_filters

    content {
      name   = cost_filter.value.name
      values = cost_filter.value.values
    }
  }

  # Which charges count toward the limit. Omitted entirely when not set so the
  # AWS defaults apply.
  dynamic "cost_types" {
    for_each = each.value.cost_types != null ? [each.value.cost_types] : []

    content {
      include_credit             = cost_types.value.include_credit
      include_discount           = cost_types.value.include_discount
      include_other_subscription = cost_types.value.include_other_subscription
      include_recurring          = cost_types.value.include_recurring
      include_refund             = cost_types.value.include_refund
      include_subscription       = cost_types.value.include_subscription
      include_support            = cost_types.value.include_support
      include_tax                = cost_types.value.include_tax
      include_upfront            = cost_types.value.include_upfront
      use_amortized              = cost_types.value.use_amortized
      use_blended                = cost_types.value.use_blended
    }
  }

  # Auto adjusting budgets derive their own limit, so limit_amount must be unset.
  dynamic "auto_adjust_data" {
    for_each = each.value.auto_adjust_data != null ? [each.value.auto_adjust_data] : []

    content {
      auto_adjust_type = auto_adjust_data.value.auto_adjust_type

      dynamic "historical_options" {
        for_each = auto_adjust_data.value.historical_options != null ? [auto_adjust_data.value.historical_options] : []

        content {
          budget_adjustment_period = historical_options.value.budget_adjustment_period
        }
      }
    }
  }

  dynamic "notification" {
    for_each = each.value.notifications

    content {
      comparison_operator = notification.value.comparison_operator
      threshold           = notification.value.threshold
      threshold_type      = notification.value.threshold_type
      notification_type   = notification.value.notification_type

      # Fall back to the module level recipients so a shared address does not
      # have to be repeated on every notification.
      subscriber_email_addresses = (
        length(notification.value.subscriber_email_addresses) > 0
        ? notification.value.subscriber_email_addresses
        : var.notification_email_addresses
      )

      subscriber_sns_topic_arns = (
        length(notification.value.subscriber_sns_topic_arns) > 0
        ? notification.value.subscriber_sns_topic_arns
        : var.notification_sns_topic_arns
      )
    }
  }

  tags = merge(
    var.tags,
    each.value.tags,
    { "Name" = coalesce(each.value.name, each.key) }
  )

  lifecycle {
    precondition {
      condition     = each.value.auto_adjust_data == null || each.value.limit_amount == null
      error_message = "limit_amount cannot be set on an auto adjusting budget, the limit is derived by AWS."
    }

    precondition {
      condition     = each.value.auto_adjust_data != null || each.value.limit_amount != null
      error_message = "limit_amount is required unless auto_adjust_data is set."
    }

    precondition {
      condition = alltrue([
        for n in each.value.notifications :
        length(n.subscriber_email_addresses) > 0 ||
        length(n.subscriber_sns_topic_arns) > 0 ||
        length(var.notification_email_addresses) > 0 ||
        length(var.notification_sns_topic_arns) > 0
      ])
      error_message = "Every notification needs at least one subscriber, set per notification or through notification_email_addresses / notification_sns_topic_arns."
    }
  }
}
