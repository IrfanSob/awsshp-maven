# AWS provider v6 variant of aws-cmk. The only change is data.aws_region.<name>.region
# in place of .name, which v6 deprecates. .region does not exist before v6, hence the
# explicit provider constraint.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

# Data sources to get the current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Create a KMS Customer Managed Key (CMK)
resource "aws_kms_key" "this" {
  description             = var.description
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation
  policy                  = data.aws_iam_policy_document.kms_key_policy.json

  tags = merge(
    var.tags,
    { "Name" = var.key_name }
  )
}

# Create an alias for the KMS key
resource "aws_kms_alias" "this" {
  name          = "alias/${var.key_alias}"
  target_key_id = aws_kms_key.this.key_id
}

# IAM Policy Document for the KMS Key
data "aws_iam_policy_document" "kms_key_policy" {
  # Allow the root user full access to the key
  statement {
    sid    = "EnableRootPermissions"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Allow CloudWatch Logs to use the key for encryption
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.region}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]
  }

  # CloudTrail
  statement {
    sid    = "AllowCloudTrailToUseKMSKey"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    actions   = ["kms:GenerateDataKey*", "kms:Decrypt*", "kms:DescribeKey"]
    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/*"
      ]
    }
  }

  # Allow named external accounts to use the key. Needed when another account
  # writes into a resource this key protects, for example an AWS Backup vault
  # that receives cross-account copies.
  dynamic "statement" {
    for_each = length(var.external_account_ids) > 0 ? [1] : []

    content {
      sid    = "AllowExternalAccountUse"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = [for id in var.external_account_ids : "arn:aws:iam::${id}:root"]
      }

      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:GenerateDataKey*",
        "kms:ReEncrypt*",
        "kms:ListKeys",
        "kms:ListAliases",
      ]

      resources = ["*"]

      # Restricts the external account to using the key through the named AWS
      # services only. Without this the account can call KMS directly and
      # decrypt anything else the key protects.
      dynamic "condition" {
        for_each = length(var.external_account_via_services) > 0 ? [1] : []

        content {
          test     = "StringLike"
          variable = "kms:ViaService"
          values   = var.external_account_via_services
        }
      }
    }
  }

  # AWS services acting on behalf of those accounts create grants rather than
  # calling the key directly, so CreateGrant is granted separately and limited
  # to grants made for an AWS resource.
  dynamic "statement" {
    for_each = length(var.external_account_ids) > 0 ? [1] : []

    content {
      sid    = "AllowExternalAccountGrants"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = [for id in var.external_account_ids : "arn:aws:iam::${id}:root"]
      }

      actions   = ["kms:CreateGrant"]
      resources = ["*"]

      condition {
        test     = "Bool"
        variable = "kms:GrantIsForAWSResource"
        values   = ["true"]
      }

      dynamic "condition" {
        for_each = length(var.external_account_via_services) > 0 ? [1] : []

        content {
          test     = "StringLike"
          variable = "kms:ViaService"
          values   = var.external_account_via_services
        }
      }
    }
  }

  # Additional service principals (toggle: additional_service_principals)
  dynamic "statement" {
    for_each = length(var.additional_service_principals) > 0 ? [1] : []

    content {
      sid    = "AllowAdditionalServicePrincipals"
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = var.additional_service_principals
      }

      actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
      resources = ["*"]
    }
  }
}
