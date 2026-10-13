variable "trail_name" {
  description = "CloudTrail trail name"
  type        = string
}

variable "create_s3_bucket" {
  description = "Create a dedicated log bucket for the trail. Set false to write into an existing bucket named by s3_bucket_name, whose policy must already allow CloudTrail delivery"
  type        = bool
  default     = true
}

variable "s3_bucket_name" {
  description = "S3 bucket name to store CloudTrail logs. Created by this module when create_s3_bucket is true, otherwise it must already exist"
  type        = string
}

variable "s3_key_prefix" {
  description = "Optional key prefix for the trail's objects, for example cloudtrail. Leave null to write to the bucket root"
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "CMK ARN used for CloudTrail log encryption"
  type        = string
}

variable "is_multi_region_trail" {
  description = "Enable multi region trail"
  type        = bool
  default     = true
}

variable "enable_log_file_validation" {
  description = "Enable log file integrity validation"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_logs" {
  description = "Also deliver trail events to a CloudWatch Logs log group, with the IAM role CloudTrail assumes to write there"
  type        = bool
  default     = false
}

variable "cloudwatch_log_group_name" {
  description = "Log group name for CloudWatch Logs delivery. Defaults to /aws/cloudtrail/<trail_name>"
  type        = string
  default     = null
}

variable "cloudwatch_log_retention_in_days" {
  description = "Retention of the CloudWatch Logs log group in days"
  type        = number
  default     = 90
}

variable "cloudwatch_log_kms_key_arn" {
  description = "CMK ARN used to encrypt the log group. The key policy must allow logs.<region>.amazonaws.com. Leave null for the default encryption"
  type        = string
  default     = null
}

variable "cloudwatch_logs_role_name" {
  description = "Name of the IAM role CloudTrail assumes to write to CloudWatch Logs. Defaults to <trail_name>-cloudwatch-logs-role"
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}
