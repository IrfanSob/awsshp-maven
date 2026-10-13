variable "budgets" {
  description = "Budgets to create, keyed by budget name. The key is used as the budget name unless name is set"
  type = map(object({
    name         = optional(string)
    budget_type  = optional(string, "COST")
    limit_amount = optional(string)
    limit_unit   = optional(string, "USD")

    time_unit         = optional(string, "MONTHLY")
    time_period_start = optional(string)
    time_period_end   = optional(string)

    # Narrow the budget to specific services, regions, accounts or tags
    cost_filters = optional(list(object({
      name   = string
      values = list(string)
    })), [])

    # Which charges count toward the limit. Omit to use the AWS defaults
    cost_types = optional(object({
      include_credit             = optional(bool)
      include_discount           = optional(bool)
      include_other_subscription = optional(bool)
      include_recurring          = optional(bool)
      include_refund             = optional(bool)
      include_subscription       = optional(bool)
      include_support            = optional(bool)
      include_tax                = optional(bool)
      include_upfront            = optional(bool)
      use_amortized              = optional(bool)
      use_blended                = optional(bool)
    }))

    # Let AWS derive the limit from forecast or history instead of a fixed amount
    auto_adjust_data = optional(object({
      auto_adjust_type = string
      historical_options = optional(object({
        budget_adjustment_period = number
      }))
    }))

    notifications = optional(list(object({
      threshold                  = number
      comparison_operator        = optional(string, "GREATER_THAN")
      threshold_type             = optional(string, "PERCENTAGE")
      notification_type          = optional(string, "ACTUAL")
      subscriber_email_addresses = optional(list(string), [])
      subscriber_sns_topic_arns  = optional(list(string), [])
    })), [])

    tags = optional(map(string), {})
  }))

  validation {
    condition = alltrue([
      for k, b in var.budgets :
      contains([
        "COST", "USAGE", "RI_UTILIZATION", "RI_COVERAGE",
        "SAVINGS_PLANS_UTILIZATION", "SAVINGS_PLANS_COVERAGE"
      ], b.budget_type)
    ])
    error_message = "budget_type must be one of: COST, USAGE, RI_UTILIZATION, RI_COVERAGE, SAVINGS_PLANS_UTILIZATION, SAVINGS_PLANS_COVERAGE."
  }

  validation {
    condition = alltrue([
      for k, b in var.budgets :
      contains(["DAILY", "MONTHLY", "QUARTERLY", "ANNUALLY"], b.time_unit)
    ])
    error_message = "time_unit must be one of: DAILY, MONTHLY, QUARTERLY, ANNUALLY."
  }

  validation {
    condition = alltrue(flatten([
      for k, b in var.budgets : [
        for n in b.notifications :
        contains(["ACTUAL", "FORECASTED"], n.notification_type)
      ]
    ]))
    error_message = "notification_type must be either ACTUAL or FORECASTED."
  }

  validation {
    condition = alltrue(flatten([
      for k, b in var.budgets : [
        for n in b.notifications :
        contains(["PERCENTAGE", "ABSOLUTE_VALUE"], n.threshold_type)
      ]
    ]))
    error_message = "threshold_type must be either PERCENTAGE or ABSOLUTE_VALUE."
  }

  validation {
    condition = alltrue(flatten([
      for k, b in var.budgets : [
        for n in b.notifications :
        contains(["GREATER_THAN", "LESS_THAN", "EQUAL_TO"], n.comparison_operator)
      ]
    ]))
    error_message = "comparison_operator must be one of: GREATER_THAN, LESS_THAN, EQUAL_TO."
  }
}

variable "notification_email_addresses" {
  description = "Default email recipients applied to any notification that does not name its own"
  type        = list(string)
  default     = []
}

variable "notification_sns_topic_arns" {
  description = "Default SNS topics applied to any notification that does not name its own"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "A map of tags to apply to all budgets"
  type        = map(string)
  default     = {}
}
