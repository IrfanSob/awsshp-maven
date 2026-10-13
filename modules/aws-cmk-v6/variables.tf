variable "description" {
  description = "The description of the KMS key."
  type        = string
  default     = "KMS key for encrypting CloudWatch Logs"
}

variable "deletion_window_in_days" {
  description = "The number of days to retain the KMS key after deletion."
  type        = number
  default     = 30
}

variable "enable_key_rotation" {
  description = "Whether to enable automatic key rotation for the KMS key."
  type        = bool
  default     = true
}

variable "key_name" {
  description = "The name of the KMS key (used for tagging)."
  type        = string
  default     = "cloudwatch-logs-key"
}

variable "key_alias" {
  description = "The alias for the KMS key."
  type        = string
  default     = "cloudwatch-logs-key"
}

variable "tags" {
  description = "A map of tags to apply to the KMS key."
  type        = map(string)
  default     = {}
}
variable "external_account_ids" {
  description = "AWS account IDs granted use of this key from outside the owning account. Needed when another account writes into a resource this key protects, such as an AWS Backup vault receiving cross-account copies. Leave empty for a single-account key"
  type        = list(string)
  default     = []
}

variable "external_account_via_services" {
  description = "Restricts external_account_ids to using this key only through the named AWS services, matched with StringLike on kms:ViaService. Strongly recommended when the key also protects unrelated data, for example \"backup.ap-northeast-1.amazonaws.com\". Leave empty to grant unconditional use"
  type        = list(string)
  default     = []
}

variable "additional_service_principals" {
  description = "Extra AWS service principals allowed to call kms:Decrypt and kms:GenerateDataKey*, for example events.amazonaws.com and cloudwatch.amazonaws.com when an SNS topic encrypted with this key receives EventBridge events or CloudWatch alarms. Leave empty to keep the default policy"
  type        = list(string)
  default     = []
}
