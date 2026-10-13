# --- General -------------------------------------------------------------------

variable "alarm_name_prefix" {
  description = "Prefix added to generated alarm and filter names (<prefix>-<key>). Ignored when a name is set explicitly"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to every alarm"
  type        = map(string)
  default     = {}
}

# --- Default actions -----------------------------------------------------------

variable "actions_enabled" {
  description = "Default for whether alarm actions run"
  type        = bool
  default     = true
}

variable "default_alarm_actions" {
  description = "Actions (usually SNS topic ARNs) used when an alarm does not set alarm_actions"
  type        = list(string)
  default     = []
}

variable "default_ok_actions" {
  description = "Actions used when an alarm does not set ok_actions"
  type        = list(string)
  default     = []
}

variable "default_insufficient_data_actions" {
  description = "Actions used when an alarm does not set insufficient_data_actions"
  type        = list(string)
  default     = []
}

variable "default_treat_missing_data" {
  description = "missing, ignore, breaching or notBreaching, used when an alarm does not set it"
  type        = string
  default     = "missing"
}

# --- Metric alarms -------------------------------------------------------------

variable "metric_alarms" {
  description = "Metric alarms keyed by a short name. Use namespace/metric_name/statistic for a single metric, metric_queries for metric math or anomaly detection (with threshold_metric_id), or promql_criteria for PromQL alarms"
  type = map(object({
    alarm_name          = optional(string)
    alarm_description   = optional(string)
    comparison_operator = optional(string)
    evaluation_periods  = optional(number)
    datapoints_to_alarm = optional(number)
    evaluation_interval = optional(number)
    threshold           = optional(number)
    threshold_metric_id = optional(string)
    treat_missing_data  = optional(string)

    namespace          = optional(string)
    metric_name        = optional(string)
    dimensions         = optional(map(string))
    period             = optional(number)
    statistic          = optional(string)
    extended_statistic = optional(string)
    unit               = optional(string)

    evaluate_low_sample_count_percentiles = optional(string)

    actions_enabled           = optional(bool)
    alarm_actions             = optional(list(string))
    ok_actions                = optional(list(string))
    insufficient_data_actions = optional(list(string))

    metric_queries = optional(list(object({
      id          = string
      account_id  = optional(string)
      expression  = optional(string)
      label       = optional(string)
      period      = optional(number)
      return_data = optional(bool)
      metric = optional(object({
        namespace   = string
        metric_name = string
        dimensions  = optional(map(string))
        period      = number
        stat        = string
        unit        = optional(string)
      }))
    })), [])

    promql_criteria = optional(object({
      query           = string
      pending_period  = optional(number)
      recovery_period = optional(number)
    }))

    warm_up_configuration = optional(object({
      warm_up_period_duration_in_minutes              = number
      only_start_evaluating_after_warm_up_period_ends = optional(bool)
    }))

    tags = optional(map(string), {})
  }))
  default = {}
}

# --- Composite alarms ----------------------------------------------------------

variable "composite_alarms" {
  description = "Composite alarms keyed by a short name. alarm_rule uses ALARM(\"name\") / OK(\"name\") expressions"
  type = map(object({
    alarm_name                = optional(string)
    alarm_description         = optional(string)
    alarm_rule                = string
    actions_enabled           = optional(bool)
    alarm_actions             = optional(list(string))
    ok_actions                = optional(list(string))
    insufficient_data_actions = optional(list(string))
    actions_suppressor = optional(object({
      alarm            = string
      extension_period = number
      wait_period      = number
    }))
    tags = optional(map(string), {})
  }))
  default = {}
}

# --- Log metric filters --------------------------------------------------------

variable "log_metric_filters" {
  description = "Log metric filters keyed by a short name, for alarms on log patterns (e.g. ERROR count)"
  type = map(object({
    name             = optional(string)
    log_group_name   = string
    pattern          = string
    metric_name      = string
    metric_namespace = string
    metric_value     = optional(string, "1")
    default_value    = optional(string)
    dimensions       = optional(map(string))
    unit             = optional(string)
  }))
  default = {}
}
