variable "name_prefix" {
  description = "Prefix used for generated monitor, subscription and topic names"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "monitors" {
  description = "Anomaly monitors to create, keyed by a short name that subscriptions refer to"
  type = map(object({
    name         = optional(string)
    monitor_type = optional(string, "DIMENSIONAL")

    # Only used when monitor_type is DIMENSIONAL. SERVICE is the only value AWS
    # currently accepts.
    monitor_dimension = optional(string, "SERVICE")

    # Only used when monitor_type is CUSTOM. A Cost Explorer expression as JSON.
    monitor_specification_json = optional(string)

    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for key, monitor in var.monitors :
      contains(["DIMENSIONAL", "CUSTOM"], monitor.monitor_type)
    ])
    error_message = "monitor_type must be DIMENSIONAL or CUSTOM."
  }

  validation {
    condition = alltrue([
      for key, monitor in var.monitors :
      monitor.monitor_type != "CUSTOM" || monitor.monitor_specification_json != null
    ])
    error_message = "A CUSTOM monitor requires monitor_specification_json."
  }
}

variable "subscriptions" {
  description = "Alert subscriptions to create, keyed by a short name"
  type = map(object({
    name      = optional(string)
    frequency = optional(string, "DAILY")

    monitor_keys = optional(list(string), [])
    monitor_arns = optional(list(string), [])

    subscriber_email_addresses = optional(list(string), [])
    subscriber_sns_topic_arns  = optional(list(string), [])

    # Add the topic this module creates as a subscriber
    use_module_sns_topic = optional(bool, false)

    # Alert only when the anomaly is at least this large
    threshold_key          = optional(string, "ANOMALY_TOTAL_IMPACT_ABSOLUTE")
    threshold_match_option = optional(string, "GREATER_THAN_OR_EQUAL")
    threshold_value        = optional(number, 100)

    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for key, subscription in var.subscriptions :
      contains(["DAILY", "IMMEDIATE", "WEEKLY"], subscription.frequency)
    ])
    error_message = "frequency must be DAILY, IMMEDIATE or WEEKLY."
  }

  validation {
    condition = alltrue([
      for key, subscription in var.subscriptions :
      contains(["ANOMALY_TOTAL_IMPACT_ABSOLUTE", "ANOMALY_TOTAL_IMPACT_PERCENTAGE"], subscription.threshold_key)
    ])
    error_message = "threshold_key must be ANOMALY_TOTAL_IMPACT_ABSOLUTE or ANOMALY_TOTAL_IMPACT_PERCENTAGE."
  }

  validation {
    condition = alltrue([
      for key, subscription in var.subscriptions :
      length(subscription.monitor_keys) > 0 || length(subscription.monitor_arns) > 0
    ])
    error_message = "Each subscription must reference at least one monitor through monitor_keys or monitor_arns."
  }

  validation {
    condition = alltrue([
      for key, subscription in var.subscriptions :
      subscription.frequency != "IMMEDIATE" || length(subscription.subscriber_email_addresses) == 0
    ])
    error_message = "IMMEDIATE frequency only supports SNS subscribers. Use DAILY or WEEKLY for email."
  }

  validation {
    condition = alltrue([
      for key, subscription in var.subscriptions :
      contains(["DAILY", "WEEKLY"], subscription.frequency) ? (
        length(subscription.subscriber_sns_topic_arns) == 0 && !subscription.use_module_sns_topic
      ) : true
    ])
    error_message = "DAILY and WEEKLY frequencies only support Email subscribers. Use IMMEDIATE for SNS."
  }
}

variable "create_sns_topic" {
  description = "Create an SNS topic for anomaly alerts, including the policy Cost Explorer needs"
  type        = bool
  default     = false
}

variable "sns_topic_name" {
  description = "SNS topic name. Defaults to <name_prefix>-cost-anomaly-topic"
  type        = string
  default     = null
  nullable    = true
}

variable "existing_sns_topic_arn" {
  description = "Existing SNS topic used when create_sns_topic is false"
  type        = string
  default     = null
  nullable    = true
}

variable "sns_kms_master_key_id" {
  description = "CMK used to encrypt the SNS topic. The key policy must allow costalerts.amazonaws.com to use it"
  type        = string
  default     = null
  nullable    = true
}

variable "sns_email_subscriptions" {
  description = "Email addresses subscribed to the SNS topic created by this module"
  type        = list(string)
  default     = []
}

variable "sns_topic_allow_account_owner_full_access" {
  description = "Add the usual account owner statement to the generated topic policy"
  type        = bool
  default     = true
}
