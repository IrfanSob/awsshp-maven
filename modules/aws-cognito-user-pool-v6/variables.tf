# --- General -------------------------------------------------------------------

variable "create_user_pool" {
  description = "Whether to create the user pool and every resource in this module"
  type        = bool
  default     = true
}

variable "name" {
  description = "User pool name"
  type        = string
}

variable "tags" {
  description = "Tags applied to the user pool"
  type        = map(string)
  default     = {}
}

# --- Sign-in and attributes ----------------------------------------------------

variable "alias_attributes" {
  description = "Attributes usable as an alias: phone_number, email, preferred_username. Conflicts with username_attributes"
  type        = list(string)
  default     = null
}

variable "username_attributes" {
  description = "Attributes usable as the username: email, phone_number. Conflicts with alias_attributes"
  type        = list(string)
  default     = null
}

variable "username_case_sensitive" {
  description = "Whether usernames are case sensitive. Null keeps the AWS default. Changing it replaces the user pool"
  type        = bool
  default     = null
}

variable "auto_verified_attributes" {
  description = "Attributes verified automatically: email, phone_number"
  type        = list(string)
  default     = null
}

variable "attributes_require_verification_before_update" {
  description = "Attributes that must be verified before an update takes effect (email, phone_number). Null skips the block"
  type        = list(string)
  default     = null
}

variable "schemas" {
  description = "Custom or standard attribute schema. Changes to existing attributes are not supported by Cognito"
  type = list(object({
    name                     = string
    attribute_data_type      = string
    developer_only_attribute = optional(bool)
    mutable                  = optional(bool)
    required                 = optional(bool)
    number_attribute_constraints = optional(object({
      min_value = optional(string)
      max_value = optional(string)
    }))
    string_attribute_constraints = optional(object({
      min_length = optional(string)
      max_length = optional(string)
    }))
  }))
  default = []
}

variable "sign_in_policy_allowed_first_auth_factors" {
  description = "First-factor sign-in methods: PASSWORD, EMAIL_OTP, SMS_OTP, WEB_AUTHN. Null skips the block"
  type        = list(string)
  default     = null
}

variable "web_authn_configuration" {
  description = "Passkey settings. user_verification is required or preferred"
  type = object({
    relying_party_id  = optional(string)
    user_verification = optional(string)
  })
  default = null
}

# --- Security ------------------------------------------------------------------

variable "deletion_protection" {
  description = "ACTIVE or INACTIVE"
  type        = string
  default     = "ACTIVE"

  validation {
    condition     = contains(["ACTIVE", "INACTIVE"], var.deletion_protection)
    error_message = "deletion_protection must be ACTIVE or INACTIVE."
  }
}

variable "user_pool_tier" {
  description = "Feature plan: LITE, ESSENTIALS or PLUS. Null keeps the AWS default"
  type        = string
  default     = null
}

variable "mfa_configuration" {
  description = "OFF, ON or OPTIONAL"
  type        = string
  default     = "OFF"

  validation {
    condition     = contains(["OFF", "ON", "OPTIONAL"], var.mfa_configuration)
    error_message = "mfa_configuration must be OFF, ON or OPTIONAL."
  }
}

variable "software_token_mfa_enabled" {
  description = "Enable TOTP software token MFA. Null skips the block"
  type        = bool
  default     = null
}

variable "email_mfa_configuration" {
  description = "Email MFA / email OTP message settings"
  type = object({
    message = optional(string)
    subject = optional(string)
  })
  default = null
}

variable "password_policy" {
  description = "Password policy. Null keeps the AWS default policy"
  type = object({
    minimum_length                   = optional(number, 12)
    password_history_size            = optional(number)
    require_lowercase                = optional(bool, true)
    require_numbers                  = optional(bool, true)
    require_symbols                  = optional(bool, true)
    require_uppercase                = optional(bool, true)
    temporary_password_validity_days = optional(number, 7)
  })
  default = {}
}

variable "user_pool_add_ons" {
  description = "Threat protection. advanced_security_mode is OFF, AUDIT or ENFORCED; custom_auth_mode is AUDIT or ENFORCED"
  type = object({
    advanced_security_mode = string
    custom_auth_mode       = optional(string)
  })
  default = null
}

variable "account_recovery_mechanisms" {
  description = "Account recovery options in priority order. name is verified_email, verified_phone_number or admin_only"
  type = list(object({
    name     = string
    priority = number
  }))
  default = []
}

variable "device_configuration" {
  description = "Device tracking settings"
  type = object({
    challenge_required_on_new_device      = optional(bool)
    device_only_remembered_on_user_prompt = optional(bool)
  })
  default = null
}

# --- Messaging -----------------------------------------------------------------

variable "admin_create_user_config" {
  description = "Admin-created user settings and invitation template"
  type = object({
    allow_admin_create_user_only = optional(bool)
    invite_message_template = optional(object({
      email_message = optional(string)
      email_subject = optional(string)
      sms_message   = optional(string)
    }))
  })
  default = null
}

variable "email_configuration" {
  description = "Email sending settings. email_sending_account is COGNITO_DEFAULT or DEVELOPER (SES, needs source_arn)"
  type = object({
    configuration_set      = optional(string)
    email_sending_account  = optional(string)
    from_email_address     = optional(string)
    reply_to_email_address = optional(string)
    source_arn             = optional(string)
  })
  default = null
}

variable "sms_configuration" {
  description = "SNS settings for SMS messages"
  type = object({
    external_id    = string
    sns_caller_arn = string
    sns_region     = optional(string)
  })
  default = null
}

variable "verification_message_template" {
  description = "Verification message templates. Conflicts with the email/sms verification message variables"
  type = object({
    default_email_option  = optional(string)
    email_message         = optional(string)
    email_message_by_link = optional(string)
    email_subject         = optional(string)
    email_subject_by_link = optional(string)
    sms_message           = optional(string)
  })
  default = null
}

variable "email_verification_message" {
  description = "Email verification message. Conflicts with verification_message_template.email_message"
  type        = string
  default     = null
}

variable "email_verification_subject" {
  description = "Email verification subject. Conflicts with verification_message_template.email_subject"
  type        = string
  default     = null
}

variable "sms_authentication_message" {
  description = "SMS authentication message, must contain {####}"
  type        = string
  default     = null
}

variable "sms_verification_message" {
  description = "SMS verification message. Conflicts with verification_message_template.sms_message"
  type        = string
  default     = null
}

variable "lambda_config" {
  description = "Lambda triggers. Each value is a Lambda ARN; versioned triggers take lambda_arn and lambda_version"
  type = object({
    create_auth_challenge          = optional(string)
    custom_message                 = optional(string)
    define_auth_challenge          = optional(string)
    post_authentication            = optional(string)
    post_confirmation              = optional(string)
    pre_authentication             = optional(string)
    pre_sign_up                    = optional(string)
    pre_token_generation           = optional(string)
    user_migration                 = optional(string)
    verify_auth_challenge_response = optional(string)
    kms_key_id                     = optional(string)
    pre_token_generation_config = optional(object({
      lambda_arn     = string
      lambda_version = string
    }))
    custom_email_sender = optional(object({
      lambda_arn     = string
      lambda_version = string
    }))
    custom_sms_sender = optional(object({
      lambda_arn     = string
      lambda_version = string
    }))
  })
  default = null
}

# --- Domain --------------------------------------------------------------------

variable "create_domain" {
  description = "Create a user pool domain, required for the OAuth2 token endpoint"
  type        = bool
  default     = false
}

variable "domain" {
  description = "Domain prefix (e.g. my-app-auth) or a custom FQDN (e.g. auth.example.com)"
  type        = string
  default     = null
}

variable "domain_certificate_arn" {
  description = "ACM certificate ARN in us-east-1, required for a custom domain"
  type        = string
  default     = null
}

variable "managed_login_version" {
  description = "1 for the classic hosted UI, 2 for managed login. Null keeps the AWS default"
  type        = number
  default     = null
}

# --- Resource servers, clients, groups and IdPs --------------------------------

variable "resource_servers" {
  description = "Resource servers keyed by a short name. scopes maps scope name to description; clients reference them as <identifier>/<scope name>"
  type = map(object({
    identifier = string
    name       = optional(string)
    scopes     = optional(map(string), {})
  }))
  default = {}
}

variable "clients" {
  description = "App clients keyed by a short name. For machine-to-machine use set generate_secret = true, allowed_oauth_flows = [\"client_credentials\"] and allowed_oauth_flows_user_pool_client = true"
  type = map(object({
    name                                          = optional(string)
    generate_secret                               = optional(bool, false)
    allowed_oauth_flows_user_pool_client          = optional(bool)
    allowed_oauth_flows                           = optional(list(string))
    allowed_oauth_scopes                          = optional(list(string))
    explicit_auth_flows                           = optional(list(string))
    supported_identity_providers                  = optional(list(string))
    callback_urls                                 = optional(list(string))
    default_redirect_uri                          = optional(string)
    logout_urls                                   = optional(list(string))
    read_attributes                               = optional(list(string))
    write_attributes                              = optional(list(string))
    access_token_validity                         = optional(number)
    id_token_validity                             = optional(number)
    refresh_token_validity                        = optional(number)
    auth_session_validity                         = optional(number)
    enable_token_revocation                       = optional(bool)
    enable_propagate_additional_user_context_data = optional(bool)
    prevent_user_existence_errors                 = optional(string, "ENABLED")
    token_validity_units = optional(object({
      access_token  = optional(string)
      id_token      = optional(string)
      refresh_token = optional(string)
    }))
    refresh_token_rotation = optional(object({
      feature                    = string
      retry_grace_period_seconds = optional(number)
    }))
    analytics_configuration = optional(object({
      application_arn  = optional(string)
      application_id   = optional(string)
      external_id      = optional(string)
      role_arn         = optional(string)
      user_data_shared = optional(bool)
    }))
  }))
  default = {}
}

variable "user_groups" {
  description = "User groups keyed by a short name"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    precedence  = optional(number)
    role_arn    = optional(string)
  }))
  default = {}
}

variable "identity_providers" {
  description = "External identity providers keyed by provider name. provider_type is SAML, OIDC, Facebook, Google, LoginWithAmazon or SignInWithApple"
  type = map(object({
    provider_name     = optional(string)
    provider_type     = string
    provider_details  = map(string)
    attribute_mapping = optional(map(string))
    idp_identifiers   = optional(list(string))
  }))
  default = {}
}

# --- Logging -------------------------------------------------------------------

variable "log_configurations" {
  description = "Log delivery settings. event_source is userNotification or userAuthEvents, log_level is ERROR or INFO. Set one destination per entry"
  type = list(object({
    event_source             = string
    log_level                = string
    cloudwatch_log_group_arn = optional(string)
    firehose_stream_arn      = optional(string)
    s3_bucket_arn            = optional(string)
  }))
  default = []
}
