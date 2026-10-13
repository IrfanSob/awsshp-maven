# Reusable Secrets Manager module.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.57.1"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

locals {
  generated_secrets = {
    for k, s in var.secrets : k => s.generate_random_password
    if s.generate_random_password != null
  }

  value_keys = nonsensitive(toset(keys(var.secret_values)))

  versioned_secrets = {
    for k, s in var.secrets : k => s
    if s.generate_random_password != null || contains(local.value_keys, k)
  }

  managed_versions   = { for k, s in local.versioned_secrets : k => s if !s.ignore_secret_changes }
  unmanaged_versions = { for k, s in local.versioned_secrets : k => s if s.ignore_secret_changes }

  secret_strings = {
    for k, s in local.versioned_secrets : k => (
      s.generate_random_password == null
      ? try(var.secret_values[k].secret_string, null)
      : (
        s.generated_password_json_key == null
        ? random_password.this[k].result
        : jsonencode(merge(s.secret_string_template, { (s.generated_password_json_key) = random_password.this[k].result }))
      )
    )
  }

  version_ids = merge(
    { for k, v in aws_secretsmanager_secret_version.managed : k => v.version_id },
    { for k, v in aws_secretsmanager_secret_version.unmanaged : k => v.version_id }
  )
}

# Generated Passwords (toggle: generate_random_password)
resource "random_password" "this" {
  for_each = local.generated_secrets

  length           = each.value.length
  special          = each.value.special
  override_special = each.value.override_special
  upper            = each.value.upper
  lower            = each.value.lower
  numeric          = each.value.numeric
  min_upper        = each.value.min_upper
  min_lower        = each.value.min_lower
  min_numeric      = each.value.min_numeric
  min_special      = each.value.min_special
  keepers          = each.value.keepers
}

# Secret
resource "aws_secretsmanager_secret" "this" {
  for_each = var.secrets

  name                           = each.value.name_prefix == null ? coalesce(each.value.name, each.key) : null
  name_prefix                    = each.value.name_prefix
  description                    = each.value.description
  kms_key_id                     = try(coalesce(each.value.kms_key_id, var.kms_key_id), null)
  recovery_window_in_days        = coalesce(each.value.recovery_window_in_days, var.recovery_window_in_days)
  force_overwrite_replica_secret = each.value.force_overwrite_replica_secret
  type                           = each.value.type

  dynamic "replica" {
    for_each = each.value.replicas

    content {
      region     = replica.value.region
      kms_key_id = replica.value.kms_key_id
    }
  }

  tags = merge(
    var.tags,
    each.value.tags,
    { Name = coalesce(each.value.name, each.value.name_prefix, each.key) }
  )
}

# Secret Value - managed by Terraform
resource "aws_secretsmanager_secret_version" "managed" {
  for_each = local.managed_versions

  secret_id      = aws_secretsmanager_secret.this[each.key].id
  secret_string  = local.secret_strings[each.key]
  secret_binary  = each.value.generate_random_password == null ? try(var.secret_values[each.key].secret_binary, null) : null
  version_stages = each.value.version_stages
}

# Secret Value - initial value only, later changes made outside Terraform are kept (toggle: ignore_secret_changes)
resource "aws_secretsmanager_secret_version" "unmanaged" {
  for_each = local.unmanaged_versions

  secret_id      = aws_secretsmanager_secret.this[each.key].id
  secret_string  = local.secret_strings[each.key]
  secret_binary  = each.value.generate_random_password == null ? try(var.secret_values[each.key].secret_binary, null) : null
  version_stages = each.value.version_stages

  lifecycle {
    ignore_changes = [secret_string, secret_binary, version_stages]
  }
}

# Resource Policy (toggle: policy_json)
resource "aws_secretsmanager_secret_policy" "this" {
  for_each = { for k, s in var.secrets : k => s if s.policy_json != null }

  secret_arn          = aws_secretsmanager_secret.this[each.key].arn
  policy              = each.value.policy_json
  block_public_policy = each.value.block_public_policy
}

# Rotation (toggle: rotation)
resource "aws_secretsmanager_secret_rotation" "this" {
  for_each = { for k, s in var.secrets : k => s.rotation if s.rotation != null }

  secret_id                         = aws_secretsmanager_secret.this[each.key].id
  rotation_lambda_arn               = each.value.lambda_arn
  rotate_immediately                = each.value.rotate_immediately
  rotation_enabled                  = each.value.rotation_enabled
  external_secret_rotation_role_arn = each.value.external_secret_rotation_role_arn

  dynamic "rotation_rules" {
    for_each = each.value.rotation_enabled == false ? [] : [1]

    content {
      automatically_after_days = each.value.automatically_after_days
      duration                 = each.value.duration
      schedule_expression      = each.value.schedule_expression
    }
  }

  dynamic "external_secret_rotation_metadata" {
    for_each = each.value.external_secret_rotation_metadata

    content {
      key   = external_secret_rotation_metadata.key
      value = external_secret_rotation_metadata.value
    }
  }

  depends_on = [
    aws_secretsmanager_secret_version.managed,
    aws_secretsmanager_secret_version.unmanaged
  ]
}
