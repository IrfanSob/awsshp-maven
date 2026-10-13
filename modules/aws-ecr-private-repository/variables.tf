variable "repositories" {
  description = "List of ECR repositories to create"
  type        = list(string)
}

variable "image_tag_mutability" {
  description = "Tag mutability setting (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "IMMUTABLE"
}

variable "scan_on_push" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "force_delete" {
  description = "Delete the repository even if it still contains images"
  type        = bool
  default     = false
}

variable "encryption_type" {
  description = "Encryption type for the repositories: AES256 or KMS"
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "encryption_type must be AES256 or KMS."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN used when encryption_type is KMS. Null uses the AWS managed key for ECR"
  type        = string
  default     = null
}

variable "create_lifecycle_policy" {
  description = "Attach a lifecycle policy to every repository. Uses lifecycle_policy_json when set, otherwise keeps the last max_image_count images and optionally expires untagged images"
  type        = bool
  default     = false
}

variable "max_image_count" {
  description = "Maximum number of images to retain when the generated lifecycle policy is used"
  type        = number
  default     = 20
}

variable "untagged_image_expiry_days" {
  description = "Days after push when untagged images expire in the generated lifecycle policy. Null skips the rule"
  type        = number
  default     = null
}

variable "lifecycle_policy_json" {
  description = "Custom lifecycle policy JSON applied to every repository instead of the generated one"
  type        = string
  default     = null
}

variable "repository_policy_json" {
  description = "Repository policy JSON applied to every repository. Null creates no repository policy"
  type        = string
  default     = null
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
