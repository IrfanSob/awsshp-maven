variable "create_bucket" {
  description = "Whether to create the bucket. Set false to disable the module without removing the block"
  type        = bool
  default     = true
}

variable "bucket_name" {
  description = "Full bucket name. Mutually exclusive with bucket_prefix"
  type        = string
  default     = null
  nullable    = true
}

variable "bucket_prefix" {
  description = "Prefix for a generated bucket name. Mutually exclusive with bucket_name"
  type        = string
  default     = null
  nullable    = true
}

variable "force_destroy" {
  description = "Allow Terraform to delete the bucket while it still holds objects"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

# --- Ownership and public access --------------------------------------------------

variable "object_ownership" {
  description = "Object ownership setting. Valid values: BucketOwnerEnforced, BucketOwnerPreferred, ObjectWriter. Set null to skip"
  type        = string
  default     = "BucketOwnerEnforced"
  nullable    = true

  validation {
    condition     = var.object_ownership == null || contains(["BucketOwnerEnforced", "BucketOwnerPreferred", "ObjectWriter"], coalesce(var.object_ownership, "BucketOwnerEnforced"))
    error_message = "object_ownership must be BucketOwnerEnforced, BucketOwnerPreferred or ObjectWriter."
  }
}

variable "acl" {
  description = "Canned ACL to apply. Only valid when object_ownership still honours ACLs. Leave null on new buckets"
  type        = string
  default     = null
  nullable    = true
}

variable "enable_public_access_block" {
  description = "Whether to manage the public access block for this bucket"
  type        = bool
  default     = true
}

variable "block_public_acls" {
  description = "Block public ACLs"
  type        = bool
  default     = true
}

variable "block_public_policy" {
  description = "Block public bucket policies"
  type        = bool
  default     = true
}

variable "ignore_public_acls" {
  description = "Ignore public ACLs"
  type        = bool
  default     = true
}

variable "restrict_public_buckets" {
  description = "Restrict public bucket policies"
  type        = bool
  default     = true
}

# --- Versioning and encryption ----------------------------------------------------

variable "versioning_status" {
  description = "Versioning status. Valid values: Enabled, Suspended, Disabled. Set null to leave versioning unmanaged"
  type        = string
  default     = "Enabled"
  nullable    = true

  validation {
    condition     = var.versioning_status == null || contains(["Enabled", "Suspended", "Disabled"], coalesce(var.versioning_status, "Enabled"))
    error_message = "versioning_status must be Enabled, Suspended or Disabled."
  }
}

variable "versioning_mfa_delete" {
  description = "MFA delete status. Valid values: Enabled, Disabled"
  type        = string
  default     = null
  nullable    = true
}

variable "versioning_mfa" {
  description = "Concatenated MFA device serial number and token, required when changing versioning_mfa_delete"
  type        = string
  default     = null
  nullable    = true
}

variable "enable_server_side_encryption" {
  description = "Whether to manage default server side encryption for this bucket"
  type        = bool
  default     = true
}

variable "sse_algorithm" {
  description = "Default encryption algorithm. Valid values: AES256, aws:kms, aws:kms:dsse"
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "aws:kms", "aws:kms:dsse"], var.sse_algorithm)
    error_message = "sse_algorithm must be AES256, aws:kms or aws:kms:dsse."
  }
}

variable "kms_key_arn" {
  description = "CMK ARN used when sse_algorithm is aws:kms. Leave null to use the AWS managed key"
  type        = string
  default     = null
  nullable    = true
}

variable "bucket_key_enabled" {
  description = "Enable S3 bucket keys to reduce KMS request cost"
  type        = bool
  default     = true
}

# --- Lifecycle --------------------------------------------------------------------

variable "lifecycle_rules" {
  description = "Lifecycle rules. A filter with two or more criteria is wrapped in an and block automatically"
  type = list(object({
    id      = string
    enabled = optional(bool, true)

    filter = optional(object({
      prefix                   = optional(string)
      tags                     = optional(map(string))
      object_size_greater_than = optional(number)
      object_size_less_than    = optional(number)
    }))

    transitions = optional(list(object({
      days          = optional(number)
      date          = optional(string)
      storage_class = string
    })), [])

    expiration = optional(object({
      days                         = optional(number)
      date                         = optional(string)
      expired_object_delete_marker = optional(bool)
    }))

    noncurrent_version_transitions = optional(list(object({
      noncurrent_days           = number
      newer_noncurrent_versions = optional(number)
      storage_class             = string
    })), [])

    noncurrent_version_expiration = optional(object({
      noncurrent_days           = number
      newer_noncurrent_versions = optional(number)
    }))

    abort_incomplete_multipart_upload_days = optional(number)
  }))
  default = []
}

# --- Logging, CORS and website ----------------------------------------------------

variable "logging" {
  description = "Server access logging target for this bucket"
  type = object({
    target_bucket = string
    target_prefix = optional(string, "")
  })
  default  = null
  nullable = true
}

variable "cors_rules" {
  description = "CORS rules"
  type = list(object({
    id              = optional(string)
    allowed_headers = optional(list(string))
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string))
    max_age_seconds = optional(number)
  }))
  default = []
}

variable "website" {
  description = "Static website configuration"
  type = object({
    index_document           = optional(string)
    error_document           = optional(string)
    redirect_all_requests_to = optional(string)
    redirect_protocol        = optional(string)
  })
  default  = null
  nullable = true
}

# --- Object lock ------------------------------------------------------------------

variable "object_lock_enabled" {
  description = "Enable object lock on the bucket. Cannot be turned on after creation and requires versioning"
  type        = bool
  default     = false
}

variable "object_lock_rule" {
  description = "Default object lock retention. Only applied when object_lock_enabled is true"
  type = object({
    mode  = string
    days  = optional(number)
    years = optional(number)
  })
  default  = null
  nullable = true

  validation {
    condition     = var.object_lock_rule == null || contains(["GOVERNANCE", "COMPLIANCE"], try(var.object_lock_rule.mode, "GOVERNANCE"))
    error_message = "object_lock_rule.mode must be GOVERNANCE or COMPLIANCE."
  }
}

# --- Bucket policy ----------------------------------------------------------------

variable "bucket_policy_json" {
  description = "Complete bucket policy JSON. When set it replaces every generated statement below"
  type        = string
  default     = null
  nullable    = true
}

variable "additional_policy_json_documents" {
  description = "Extra policy JSON documents merged into the generated bucket policy"
  type        = list(string)
  default     = []
}

variable "attach_deny_insecure_transport_policy" {
  description = "Deny any request that does not use TLS"
  type        = bool
  default     = true
}

variable "attach_deny_unencrypted_object_upload_policy" {
  description = "Deny uploads that do not request server side encryption"
  type        = bool
  default     = false
}

variable "attach_lb_log_delivery_policy" {
  description = "Allow Elastic Load Balancing to write access logs into this bucket"
  type        = bool
  default     = false
}

variable "lb_log_delivery_principal_type" {
  description = "How ELB delivers logs. Use service for regions launched from 2022 onward such as ap-southeast-3, account for older regions"
  type        = string
  default     = "service"

  validation {
    condition     = contains(["service", "account"], var.lb_log_delivery_principal_type)
    error_message = "lb_log_delivery_principal_type must be service or account."
  }
}

variable "lb_log_delivery_account_ids" {
  description = "Regional ELB account IDs, required when lb_log_delivery_principal_type is account"
  type        = list(string)
  default     = []
}

variable "attach_s3_access_log_delivery_policy" {
  description = "Allow S3 server access logging from other buckets to write into this bucket"
  type        = bool
  default     = false
}

variable "attach_delivery_logs_policy" {
  description = "Allow delivery.logs.amazonaws.com, used by VPC flow logs and ELB connection logs, to write into this bucket"
  type        = bool
  default     = false
}

variable "log_delivery_source_account_ids" {
  description = "Accounts allowed to deliver logs here. Defaults to the account holding the bucket"
  type        = list(string)
  default     = []
}

variable "log_delivery_prefix" {
  description = "Key prefix for delivered logs. Include the trailing slash, for example alb/"
  type        = string
  default     = ""
}

variable "attach_cloudtrail_log_delivery_policy" {
  description = "Allow CloudTrail to write trail logs into this bucket. Use it when the trail does not own its bucket, for example a shared log bucket"
  type        = bool
  default     = false
}

variable "cloudtrail_source_arns" {
  description = "Trail ARNs allowed to deliver here, matched on aws:SourceArn. Leave empty to scope delivery by aws:SourceAccount to log_delivery_source_account_ids instead"
  type        = list(string)
  default     = []
}

variable "cloudtrail_log_prefix" {
  description = "S3 key prefix set on the trail. Include the trailing slash, for example cloudtrail/. Leave empty when the trail writes to the bucket root"
  type        = string
  default     = ""
}
