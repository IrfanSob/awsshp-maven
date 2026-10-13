# --- General -------------------------------------------------------------------

variable "kms_key_id" {
  description = "Default KMS key ARN or ID for every secret. Null uses aws/secretsmanager"
  type        = string
  default     = null
}

variable "recovery_window_in_days" {
  description = "Default days before a deleted secret is removed: 0 for immediate deletion or 7-30"
  type        = number
  default     = 30

  validation {
    condition     = var.recovery_window_in_days == 0 || (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30)
    error_message = "recovery_window_in_days must be 0 or between 7 and 30."
  }
}

variable "tags" {
  description = "Tags applied to every secret"
  type        = map(string)
  default     = {}
}

# --- Secrets -------------------------------------------------------------------

variable "secrets" {
  description = "Secrets keyed by a short name. The value comes from generate_random_password or from secret_values with the same key; a secret with neither gets no version. generated_password_json_key stores the password as that key inside secret_string_template, otherwise the secret holds the bare password"
  type = map(object({
    name                           = optional(string)
    name_prefix                    = optional(string)
    description                    = optional(string)
    kms_key_id                     = optional(string)
    recovery_window_in_days        = optional(number)
    force_overwrite_replica_secret = optional(bool)
    type                           = optional(string)

    replicas = optional(list(object({
      region     = string
      kms_key_id = optional(string)
    })), [])

    generate_random_password = optional(object({
      length           = optional(number, 32)
      special          = optional(bool, true)
      override_special = optional(string)
      upper            = optional(bool, true)
      lower            = optional(bool, true)
      numeric          = optional(bool, true)
      min_upper        = optional(number, 0)
      min_lower        = optional(number, 0)
      min_numeric      = optional(number, 0)
      min_special      = optional(number, 0)
      keepers          = optional(map(string))
    }))
    generated_password_json_key = optional(string)
    secret_string_template      = optional(map(string), {})

    version_stages        = optional(list(string))
    ignore_secret_changes = optional(bool, false)

    policy_json         = optional(string)
    block_public_policy = optional(bool)

    rotation = optional(object({
      lambda_arn                        = optional(string)
      automatically_after_days          = optional(number)
      duration                          = optional(string)
      schedule_expression               = optional(string)
      rotate_immediately                = optional(bool)
      rotation_enabled                  = optional(bool)
      external_secret_rotation_role_arn = optional(string)
      external_secret_rotation_metadata = optional(map(string), {})
    }))

    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, s in var.secrets : !(s.name != null && s.name_prefix != null)
    ])
    error_message = "Set either name or name_prefix on a secret, not both."
  }
}

variable "secret_values" {
  description = "Secret values supplied by the caller, keyed like secrets. Set secret_string or base64 secret_binary"
  type = map(object({
    secret_string = optional(string)
    secret_binary = optional(string)
  }))
  default   = {}
  sensitive = true
}
