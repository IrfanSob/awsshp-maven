# --- General -------------------------------------------------------------------

variable "create_topic" {
  description = "Whether to create the topic and every resource in this module"
  type        = bool
  default     = true
}

variable "name" {
  description = "Topic name. .fifo is appended automatically for FIFO topics"
  type        = string
}

variable "display_name" {
  description = "Display name, used as the sender name for SMS"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the topic"
  type        = map(string)
  default     = {}
}

# --- Topic settings ------------------------------------------------------------

variable "kms_master_key_id" {
  description = "KMS key for server-side encryption. A CMK must allow the publishing services (e.g. events.amazonaws.com, cloudwatch.amazonaws.com); alias/aws/sns does not work for them. Null disables encryption"
  type        = string
  default     = null
}

variable "delivery_policy" {
  description = "Delivery policy JSON (HTTP/S retries)"
  type        = string
  default     = null
}


variable "signature_version" {
  description = "Message signature version: 1 (SHA1) or 2 (SHA256)"
  type        = number
  default     = null
}

variable "tracing_config" {
  description = "PassThrough or Active (X-Ray)"
  type        = string
  default     = null
}

variable "fifo_topic" {
  description = "Create a FIFO topic"
  type        = bool
  default     = false
}

variable "fifo_throughput_scope" {
  description = "Topic or MessageGroup (FIFO only)"
  type        = string
  default     = null
}

variable "content_based_deduplication" {
  description = "Content-based deduplication (FIFO only)"
  type        = bool
  default     = null
}

variable "archive_policy" {
  description = "Message archive policy JSON (FIFO only)"
  type        = string
  default     = null
}

variable "delivery_status_logging" {
  description = "Delivery status logging per protocol (application, http, lambda, sqs, firehose)"
  type = object({
    application = optional(object({ success_role_arn = optional(string), success_sample_rate = optional(number), failure_role_arn = optional(string) }))
    http        = optional(object({ success_role_arn = optional(string), success_sample_rate = optional(number), failure_role_arn = optional(string) }))
    lambda      = optional(object({ success_role_arn = optional(string), success_sample_rate = optional(number), failure_role_arn = optional(string) }))
    sqs         = optional(object({ success_role_arn = optional(string), success_sample_rate = optional(number), failure_role_arn = optional(string) }))
    firehose    = optional(object({ success_role_arn = optional(string), success_sample_rate = optional(number), failure_role_arn = optional(string) }))
  })
  default = {}
}

# --- Policy --------------------------------------------------------------------

variable "create_topic_policy" {
  description = "Manage the topic policy: account owner access, publisher_service_principals and the extra documents below"
  type        = bool
  default     = true
}

variable "publisher_service_principals" {
  description = "AWS services allowed to publish from this account, e.g. events.amazonaws.com, cloudwatch.amazonaws.com, budgets.amazonaws.com, codestar-notifications.amazonaws.com"
  type        = list(string)
  default     = []
}

variable "enforce_secure_transport" {
  description = "Deny publishing over non-TLS connections"
  type        = bool
  default     = true
}

variable "additional_policy_json_documents" {
  description = "Extra policy JSON documents merged into the topic policy"
  type        = list(string)
  default     = []
}

variable "policy_json" {
  description = "Policy JSON whose statements override generated ones with the same Sid"
  type        = string
  default     = null
}

# --- Subscriptions -------------------------------------------------------------

variable "subscriptions" {
  description = "Subscriptions keyed by a short name. Email endpoints must confirm the subscription before they receive messages"
  type = map(object({
    protocol                        = string
    endpoint                        = string
    subscription_role_arn           = optional(string)
    confirmation_timeout_in_minutes = optional(number)
    endpoint_auto_confirms          = optional(bool)
    delivery_policy                 = optional(string)
    filter_policy                   = optional(string)
    filter_policy_scope             = optional(string)
    raw_message_delivery            = optional(bool)
    redrive_policy                  = optional(string)
    replay_policy                   = optional(string)
  }))
  default = {}
}
