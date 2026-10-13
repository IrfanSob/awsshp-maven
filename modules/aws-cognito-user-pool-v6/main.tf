# Reusable Cognito User Pool module.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.5.0"
    }
  }
}

data "aws_region" "current" {}

locals {
  user_pool_id = one(aws_cognito_user_pool.this[*].id)

  is_custom_domain = var.domain != null && strcontains(coalesce(var.domain, "-"), ".")

  domain_base_url = (
    var.create_user_pool && var.create_domain
    ? (
      local.is_custom_domain
      ? "https://${var.domain}"
      : "https://${var.domain}.auth.${data.aws_region.current.region}.amazoncognito.com"
    )
    : null
  )
}

# User Pool
resource "aws_cognito_user_pool" "this" {
  count = var.create_user_pool ? 1 : 0

  name                       = var.name
  alias_attributes           = var.alias_attributes
  username_attributes        = var.username_attributes
  auto_verified_attributes   = var.auto_verified_attributes
  deletion_protection        = var.deletion_protection
  mfa_configuration          = var.mfa_configuration
  user_pool_tier             = var.user_pool_tier
  email_verification_message = var.email_verification_message
  email_verification_subject = var.email_verification_subject
  sms_authentication_message = var.sms_authentication_message
  sms_verification_message   = var.sms_verification_message

  dynamic "account_recovery_setting" {
    for_each = length(var.account_recovery_mechanisms) > 0 ? [1] : []

    content {
      dynamic "recovery_mechanism" {
        for_each = var.account_recovery_mechanisms

        content {
          name     = recovery_mechanism.value.name
          priority = recovery_mechanism.value.priority
        }
      }
    }
  }

  dynamic "admin_create_user_config" {
    for_each = var.admin_create_user_config != null ? [var.admin_create_user_config] : []

    content {
      allow_admin_create_user_only = admin_create_user_config.value.allow_admin_create_user_only

      dynamic "invite_message_template" {
        for_each = admin_create_user_config.value.invite_message_template != null ? [admin_create_user_config.value.invite_message_template] : []

        content {
          email_message = invite_message_template.value.email_message
          email_subject = invite_message_template.value.email_subject
          sms_message   = invite_message_template.value.sms_message
        }
      }
    }
  }

  dynamic "device_configuration" {
    for_each = var.device_configuration != null ? [var.device_configuration] : []

    content {
      challenge_required_on_new_device      = device_configuration.value.challenge_required_on_new_device
      device_only_remembered_on_user_prompt = device_configuration.value.device_only_remembered_on_user_prompt
    }
  }

  dynamic "email_configuration" {
    for_each = var.email_configuration != null ? [var.email_configuration] : []

    content {
      configuration_set      = email_configuration.value.configuration_set
      email_sending_account  = email_configuration.value.email_sending_account
      from_email_address     = email_configuration.value.from_email_address
      reply_to_email_address = email_configuration.value.reply_to_email_address
      source_arn             = email_configuration.value.source_arn
    }
  }

  dynamic "email_mfa_configuration" {
    for_each = var.email_mfa_configuration != null ? [var.email_mfa_configuration] : []

    content {
      message = email_mfa_configuration.value.message
      subject = email_mfa_configuration.value.subject
    }
  }

  dynamic "lambda_config" {
    for_each = var.lambda_config != null ? [var.lambda_config] : []

    content {
      create_auth_challenge          = lambda_config.value.create_auth_challenge
      custom_message                 = lambda_config.value.custom_message
      define_auth_challenge          = lambda_config.value.define_auth_challenge
      post_authentication            = lambda_config.value.post_authentication
      post_confirmation              = lambda_config.value.post_confirmation
      pre_authentication             = lambda_config.value.pre_authentication
      pre_sign_up                    = lambda_config.value.pre_sign_up
      pre_token_generation           = lambda_config.value.pre_token_generation
      user_migration                 = lambda_config.value.user_migration
      verify_auth_challenge_response = lambda_config.value.verify_auth_challenge_response
      kms_key_id                     = lambda_config.value.kms_key_id

      dynamic "pre_token_generation_config" {
        for_each = lambda_config.value.pre_token_generation_config != null ? [lambda_config.value.pre_token_generation_config] : []

        content {
          lambda_arn     = pre_token_generation_config.value.lambda_arn
          lambda_version = pre_token_generation_config.value.lambda_version
        }
      }

      dynamic "custom_email_sender" {
        for_each = lambda_config.value.custom_email_sender != null ? [lambda_config.value.custom_email_sender] : []

        content {
          lambda_arn     = custom_email_sender.value.lambda_arn
          lambda_version = custom_email_sender.value.lambda_version
        }
      }

      dynamic "custom_sms_sender" {
        for_each = lambda_config.value.custom_sms_sender != null ? [lambda_config.value.custom_sms_sender] : []

        content {
          lambda_arn     = custom_sms_sender.value.lambda_arn
          lambda_version = custom_sms_sender.value.lambda_version
        }
      }
    }
  }

  dynamic "password_policy" {
    for_each = var.password_policy != null ? [var.password_policy] : []

    content {
      minimum_length                   = password_policy.value.minimum_length
      password_history_size            = password_policy.value.password_history_size
      require_lowercase                = password_policy.value.require_lowercase
      require_numbers                  = password_policy.value.require_numbers
      require_symbols                  = password_policy.value.require_symbols
      require_uppercase                = password_policy.value.require_uppercase
      temporary_password_validity_days = password_policy.value.temporary_password_validity_days
    }
  }

  dynamic "schema" {
    for_each = var.schemas

    content {
      name                     = schema.value.name
      attribute_data_type      = schema.value.attribute_data_type
      developer_only_attribute = schema.value.developer_only_attribute
      mutable                  = schema.value.mutable
      required                 = schema.value.required

      dynamic "number_attribute_constraints" {
        for_each = schema.value.number_attribute_constraints != null ? [schema.value.number_attribute_constraints] : []

        content {
          min_value = number_attribute_constraints.value.min_value
          max_value = number_attribute_constraints.value.max_value
        }
      }

      dynamic "string_attribute_constraints" {
        for_each = schema.value.string_attribute_constraints != null ? [schema.value.string_attribute_constraints] : []

        content {
          min_length = string_attribute_constraints.value.min_length
          max_length = string_attribute_constraints.value.max_length
        }
      }
    }
  }

  dynamic "sign_in_policy" {
    for_each = var.sign_in_policy_allowed_first_auth_factors != null ? [1] : []

    content {
      allowed_first_auth_factors = var.sign_in_policy_allowed_first_auth_factors
    }
  }

  dynamic "sms_configuration" {
    for_each = var.sms_configuration != null ? [var.sms_configuration] : []

    content {
      external_id    = sms_configuration.value.external_id
      sns_caller_arn = sms_configuration.value.sns_caller_arn
      sns_region     = sms_configuration.value.sns_region
    }
  }

  dynamic "software_token_mfa_configuration" {
    for_each = var.software_token_mfa_enabled != null ? [1] : []

    content {
      enabled = var.software_token_mfa_enabled
    }
  }

  dynamic "user_attribute_update_settings" {
    for_each = var.attributes_require_verification_before_update != null ? [1] : []

    content {
      attributes_require_verification_before_update = var.attributes_require_verification_before_update
    }
  }

  dynamic "user_pool_add_ons" {
    for_each = var.user_pool_add_ons != null ? [var.user_pool_add_ons] : []

    content {
      advanced_security_mode = user_pool_add_ons.value.advanced_security_mode

      dynamic "advanced_security_additional_flows" {
        for_each = user_pool_add_ons.value.custom_auth_mode != null ? [1] : []

        content {
          custom_auth_mode = user_pool_add_ons.value.custom_auth_mode
        }
      }
    }
  }

  dynamic "username_configuration" {
    for_each = var.username_case_sensitive != null ? [1] : []

    content {
      case_sensitive = var.username_case_sensitive
    }
  }

  dynamic "verification_message_template" {
    for_each = var.verification_message_template != null ? [var.verification_message_template] : []

    content {
      default_email_option  = verification_message_template.value.default_email_option
      email_message         = verification_message_template.value.email_message
      email_message_by_link = verification_message_template.value.email_message_by_link
      email_subject         = verification_message_template.value.email_subject
      email_subject_by_link = verification_message_template.value.email_subject_by_link
      sms_message           = verification_message_template.value.sms_message
    }
  }

  dynamic "web_authn_configuration" {
    for_each = var.web_authn_configuration != null ? [var.web_authn_configuration] : []

    content {
      relying_party_id  = web_authn_configuration.value.relying_party_id
      user_verification = web_authn_configuration.value.user_verification
    }
  }

  tags = merge(
    var.tags,
    { Name = var.name }
  )

  lifecycle {
    precondition {
      condition     = !(length(coalesce(var.alias_attributes, [])) > 0 && length(coalesce(var.username_attributes, [])) > 0)
      error_message = "Set either alias_attributes or username_attributes, not both."
    }
  }
}

# User Pool Domain (toggle: create_domain)
resource "aws_cognito_user_pool_domain" "this" {
  count = var.create_user_pool && var.create_domain ? 1 : 0

  domain                = var.domain
  user_pool_id          = local.user_pool_id
  certificate_arn       = var.domain_certificate_arn
  managed_login_version = var.managed_login_version

  lifecycle {
    precondition {
      condition     = var.domain != null
      error_message = "domain is required when create_domain is true."
    }

    precondition {
      condition     = !local.is_custom_domain || var.domain_certificate_arn != null
      error_message = "A custom domain needs domain_certificate_arn (an ACM certificate in us-east-1)."
    }
  }
}

# Resource Servers
resource "aws_cognito_resource_server" "this" {
  for_each = var.create_user_pool ? var.resource_servers : {}

  identifier   = each.value.identifier
  name         = coalesce(each.value.name, each.key)
  user_pool_id = local.user_pool_id

  dynamic "scope" {
    for_each = each.value.scopes

    content {
      scope_name        = scope.key
      scope_description = scope.value
    }
  }
}

# Identity Providers
resource "aws_cognito_identity_provider" "this" {
  for_each = var.create_user_pool ? var.identity_providers : {}

  user_pool_id      = local.user_pool_id
  provider_name     = coalesce(each.value.provider_name, each.key)
  provider_type     = each.value.provider_type
  provider_details  = each.value.provider_details
  attribute_mapping = each.value.attribute_mapping
  idp_identifiers   = each.value.idp_identifiers
}

# App Clients
resource "aws_cognito_user_pool_client" "this" {
  for_each = var.create_user_pool ? var.clients : {}

  name         = coalesce(each.value.name, each.key)
  user_pool_id = local.user_pool_id

  generate_secret                               = each.value.generate_secret
  allowed_oauth_flows_user_pool_client          = each.value.allowed_oauth_flows_user_pool_client
  allowed_oauth_flows                           = each.value.allowed_oauth_flows
  allowed_oauth_scopes                          = each.value.allowed_oauth_scopes
  explicit_auth_flows                           = each.value.explicit_auth_flows
  supported_identity_providers                  = each.value.supported_identity_providers
  callback_urls                                 = each.value.callback_urls
  default_redirect_uri                          = each.value.default_redirect_uri
  logout_urls                                   = each.value.logout_urls
  read_attributes                               = each.value.read_attributes
  write_attributes                              = each.value.write_attributes
  access_token_validity                         = each.value.access_token_validity
  id_token_validity                             = each.value.id_token_validity
  refresh_token_validity                        = each.value.refresh_token_validity
  auth_session_validity                         = each.value.auth_session_validity
  enable_token_revocation                       = each.value.enable_token_revocation
  enable_propagate_additional_user_context_data = each.value.enable_propagate_additional_user_context_data
  prevent_user_existence_errors                 = each.value.prevent_user_existence_errors

  dynamic "token_validity_units" {
    for_each = each.value.token_validity_units != null ? [each.value.token_validity_units] : []

    content {
      access_token  = token_validity_units.value.access_token
      id_token      = token_validity_units.value.id_token
      refresh_token = token_validity_units.value.refresh_token
    }
  }

  dynamic "refresh_token_rotation" {
    for_each = each.value.refresh_token_rotation != null ? [each.value.refresh_token_rotation] : []

    content {
      feature                    = refresh_token_rotation.value.feature
      retry_grace_period_seconds = refresh_token_rotation.value.retry_grace_period_seconds
    }
  }

  dynamic "analytics_configuration" {
    for_each = each.value.analytics_configuration != null ? [each.value.analytics_configuration] : []

    content {
      application_arn  = analytics_configuration.value.application_arn
      application_id   = analytics_configuration.value.application_id
      external_id      = analytics_configuration.value.external_id
      role_arn         = analytics_configuration.value.role_arn
      user_data_shared = analytics_configuration.value.user_data_shared
    }
  }

  depends_on = [
    aws_cognito_resource_server.this,
    aws_cognito_identity_provider.this
  ]
}

# User Groups
resource "aws_cognito_user_group" "this" {
  for_each = var.create_user_pool ? var.user_groups : {}

  name         = coalesce(each.value.name, each.key)
  user_pool_id = local.user_pool_id
  description  = each.value.description
  precedence   = each.value.precedence
  role_arn     = each.value.role_arn
}

# Log Delivery (toggle: log_configurations, requires the Essentials or Plus tier)
resource "aws_cognito_log_delivery_configuration" "this" {
  count = var.create_user_pool && length(var.log_configurations) > 0 ? 1 : 0

  user_pool_id = local.user_pool_id

  dynamic "log_configurations" {
    for_each = var.log_configurations

    content {
      event_source = log_configurations.value.event_source
      log_level    = log_configurations.value.log_level

      dynamic "cloud_watch_logs_configuration" {
        for_each = log_configurations.value.cloudwatch_log_group_arn != null ? [1] : []

        content {
          log_group_arn = log_configurations.value.cloudwatch_log_group_arn
        }
      }

      dynamic "firehose_configuration" {
        for_each = log_configurations.value.firehose_stream_arn != null ? [1] : []

        content {
          stream_arn = log_configurations.value.firehose_stream_arn
        }
      }

      dynamic "s3_configuration" {
        for_each = log_configurations.value.s3_bucket_arn != null ? [1] : []

        content {
          bucket_arn = log_configurations.value.s3_bucket_arn
        }
      }
    }
  }
}
