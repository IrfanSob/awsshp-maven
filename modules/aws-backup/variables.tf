variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "backup_vault_name" {
  description = "AWS Backup vault name"
  type        = string
}

variable "backup_plan_name" {
  description = "AWS Backup plan name"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for AWS Backup vault encryption"
  type        = string
  default     = null
  nullable    = true
}

variable "backup_rules" {
  description = "List of AWS Backup rules"
  type = list(object({
    rule_name                = string
    schedule                 = string
    start_window             = optional(number)
    completion_window        = optional(number)
    enable_continuous_backup = optional(bool)
    cold_storage_after       = optional(number)
    delete_after             = number
    recovery_point_tags      = optional(map(string), {})
    copy_actions = optional(list(object({
      destination_vault_arn = string
      cold_storage_after    = optional(number)
      delete_after          = number
    })), [])
  }))
}

variable "backup_selections" {
  description = "Map of backup selections"
  type = map(object({
    name          = string
    resources     = optional(list(string), [])
    not_resources = optional(list(string), [])
    selection_tags = optional(list(object({
      type  = string
      key   = string
      value = string
    })), [])
    conditions = optional(list(object({
      string_equals = optional(list(object({
        key   = string
        value = string
      })), [])
      string_like = optional(list(object({
        key   = string
        value = string
      })), [])
      string_not_equals = optional(list(object({
        key   = string
        value = string
      })), [])
      string_not_like = optional(list(object({
        key   = string
        value = string
      })), [])
    })), [])
  }))
  default = {}
}

variable "create_iam_role" {
  description = "Whether to create IAM role for AWS Backup"
  type        = bool
  default     = true
}

variable "iam_role_name" {
  description = "Custom IAM role name for AWS Backup"
  type        = string
  default     = null
  nullable    = true
}

variable "existing_iam_role_arn" {
  description = "Existing IAM role ARN for AWS Backup if create_iam_role is false"
  type        = string
  default     = null
  nullable    = true
}

variable "attach_restore_policy" {
  description = "Whether to attach restore policy to AWS Backup IAM role"
  type        = bool
  default     = false
}

variable "advanced_backup_settings" {
  description = "Advanced backup settings, for example Windows VSS for EC2"
  type = list(object({
    resource_type  = string
    backup_options = map(string)
  }))
  default = []
}

variable "enable_vault_lock" {
  description = "Whether to enable AWS Backup Vault Lock"
  type        = bool
  default     = false
}

variable "vault_lock_changeable_for_days" {
  description = "Number of days before vault lock becomes immutable"
  type        = number
  default     = null
  nullable    = true
}

variable "vault_lock_min_retention_days" {
  description = "Minimum retention days for vault lock"
  type        = number
  default     = null
  nullable    = true
}

variable "vault_lock_max_retention_days" {
  description = "Maximum retention days for vault lock"
  type        = number
  default     = null
  nullable    = true
}

variable "enable_vault_notifications" {
  description = "Whether to enable backup vault notifications"
  type        = bool
  default     = false
}

variable "backup_vault_events" {
  description = "Backup vault notification events"
  type        = list(string)
  default = [
    "BACKUP_JOB_COMPLETED",
    "BACKUP_JOB_FAILED",
    "RESTORE_JOB_COMPLETED",
    "RESTORE_JOB_FAILED"
  ]
}

variable "create_sns_topic" {
  description = "Whether to create SNS topic for backup notifications"
  type        = bool
  default     = false
}

variable "sns_topic_name" {
  description = "SNS topic name"
  type        = string
  default     = null
  nullable    = true
}

variable "existing_sns_topic_arn" {
  description = "Existing SNS topic ARN for backup notifications"
  type        = string
  default     = null
  nullable    = true
}

variable "sns_kms_master_key_id" {
  description = "SNS KMS key ID/ARN/alias"
  type        = string
  default     = null
  nullable    = true
}

variable "sns_email_subscriptions" {
  description = "SNS email subscriptions"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
variable "create_vault_policy" {
  description = "Whether to attach an access policy to the vault. Required on a vault that receives copies from another account"
  type        = bool
  default     = false
}

variable "vault_policy_allowed_account_ids" {
  description = "AWS account IDs allowed to copy recovery points into this vault. Ignored when vault_policy_json is set"
  type        = list(string)
  default     = []
}

variable "vault_policy_json" {
  description = "Full vault access policy as a JSON string. Takes precedence over vault_policy_allowed_account_ids"
  type        = string
  default     = null
}
