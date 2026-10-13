data "aws_caller_identity" "current" {}

locals {
  # Vault access policy. Only needed on a vault that receives copies from
  # another account, where the copying account must be granted CopyIntoBackupVault.
  vault_policy = var.vault_policy_json != null ? var.vault_policy_json : jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCopyIntoBackupVault"
      Effect = "Allow"
      Principal = {
        AWS = [for id in var.vault_policy_allowed_account_ids : "arn:aws:iam::${id}:root"]
      }
      Action   = "backup:CopyIntoBackupVault"
      Resource = "*"
    }]
  })
}

data "aws_iam_policy_document" "aws_backup_assume_role" {
  count = var.create_iam_role ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  count = var.create_iam_role ? 1 : 0

  name               = var.iam_role_name != null ? var.iam_role_name : "${var.name_prefix}-aws-backup-role"
  assume_role_policy = data.aws_iam_policy_document.aws_backup_assume_role[0].json

  tags = merge(
    var.tags,
    {
      Name = var.iam_role_name != null ? var.iam_role_name : "${var.name_prefix}-aws-backup-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "backup_service_role" {
  count = var.create_iam_role ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore_service_role" {
  count = var.create_iam_role && var.attach_restore_policy ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_backup_vault" "this" {
  name        = var.backup_vault_name
  kms_key_arn = var.kms_key_arn

  tags = merge(
    var.tags,
    {
      Name = var.backup_vault_name
    }
  )
}

resource "aws_backup_vault_lock_configuration" "this" {
  count = var.enable_vault_lock ? 1 : 0

  backup_vault_name   = aws_backup_vault.this.name
  changeable_for_days = var.vault_lock_changeable_for_days
  min_retention_days  = var.vault_lock_min_retention_days
  max_retention_days  = var.vault_lock_max_retention_days
}

resource "aws_sns_topic" "this" {
  count = var.create_sns_topic ? 1 : 0

  name              = var.sns_topic_name != null ? var.sns_topic_name : "${var.name_prefix}-backup-notification-topic"
  kms_master_key_id = var.sns_kms_master_key_id

  tags = merge(
    var.tags,
    {
      Name = var.sns_topic_name != null ? var.sns_topic_name : "${var.name_prefix}-backup-notification-topic"
    }
  )
}

resource "aws_sns_topic_subscription" "email" {
  for_each = var.create_sns_topic ? toset(var.sns_email_subscriptions) : []

  topic_arn = aws_sns_topic.this[0].arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_backup_vault_notifications" "this" {
  count = var.enable_vault_notifications ? 1 : 0

  backup_vault_name   = aws_backup_vault.this.name
  sns_topic_arn       = var.create_sns_topic ? aws_sns_topic.this[0].arn : var.existing_sns_topic_arn
  backup_vault_events = var.backup_vault_events
}

resource "aws_backup_vault_policy" "this" {
  count = var.create_vault_policy ? 1 : 0

  backup_vault_name = aws_backup_vault.this.name
  policy            = local.vault_policy

  lifecycle {
    precondition {
      condition     = var.vault_policy_json != null || length(var.vault_policy_allowed_account_ids) > 0
      error_message = "Set either vault_policy_json or vault_policy_allowed_account_ids when create_vault_policy is true."
    }
  }
}

resource "aws_backup_plan" "this" {
  name = var.backup_plan_name

  dynamic "rule" {
    for_each = var.backup_rules

    content {
      rule_name                = rule.value.rule_name
      target_vault_name        = aws_backup_vault.this.name
      schedule                 = rule.value.schedule
      start_window             = try(rule.value.start_window, null)
      completion_window        = try(rule.value.completion_window, null)
      enable_continuous_backup = try(rule.value.enable_continuous_backup, null)
      recovery_point_tags      = try(rule.value.recovery_point_tags, {})

      lifecycle {
        cold_storage_after = try(rule.value.cold_storage_after, null)
        delete_after       = rule.value.delete_after
      }

      dynamic "copy_action" {
        for_each = try(rule.value.copy_actions, [])

        content {
          destination_vault_arn = copy_action.value.destination_vault_arn

          lifecycle {
            cold_storage_after = try(copy_action.value.cold_storage_after, null)
            delete_after       = copy_action.value.delete_after
          }
        }
      }
    }
  }

  dynamic "advanced_backup_setting" {
    for_each = var.advanced_backup_settings

    content {
      resource_type   = advanced_backup_setting.value.resource_type
      backup_options  = advanced_backup_setting.value.backup_options
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.backup_plan_name
    }
  )
}

resource "aws_backup_selection" "this" {
  for_each = var.backup_selections

  name         = each.value.name
  plan_id      = aws_backup_plan.this.id
  iam_role_arn = var.create_iam_role ? aws_iam_role.this[0].arn : var.existing_iam_role_arn

  resources     = try(each.value.resources, [])
  not_resources = try(each.value.not_resources, [])

  dynamic "selection_tag" {
    for_each = try(each.value.selection_tags, [])

    content {
      type  = selection_tag.value.type
      key   = selection_tag.value.key
      value = selection_tag.value.value
    }
  }

  dynamic "condition" {
    for_each = try(each.value.conditions, [])

    content {
      dynamic "string_equals" {
        for_each = try(condition.value.string_equals, [])

        content {
          key   = string_equals.value.key
          value = string_equals.value.value
        }
      }

      dynamic "string_like" {
        for_each = try(condition.value.string_like, [])

        content {
          key   = string_like.value.key
          value = string_like.value.value
        }
      }

      dynamic "string_not_equals" {
        for_each = try(condition.value.string_not_equals, [])

        content {
          key   = string_not_equals.value.key
          value = string_not_equals.value.value
        }
      }

      dynamic "string_not_like" {
        for_each = try(condition.value.string_not_like, [])

        content {
          key   = string_not_like.value.key
          value = string_not_like.value.value
        }
      }
    }
  }
}