# Reusable SNS topic module.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  topic_arn  = one(aws_sns_topic.this[*].arn)
  topic_name = var.fifo_topic && !endswith(var.name, ".fifo") ? "${var.name}.fifo" : var.name
}

# Topic
resource "aws_sns_topic" "this" {
  count = var.create_topic ? 1 : 0

  name                        = local.topic_name
  display_name                = var.display_name
  kms_master_key_id           = var.kms_master_key_id
  delivery_policy             = var.delivery_policy
  signature_version           = var.signature_version
  tracing_config              = var.tracing_config
  fifo_topic                  = var.fifo_topic ? true : null
  fifo_throughput_scope       = var.fifo_topic ? var.fifo_throughput_scope : null
  content_based_deduplication = var.fifo_topic ? var.content_based_deduplication : null
  archive_policy              = var.fifo_topic ? var.archive_policy : null

  application_success_feedback_role_arn    = try(var.delivery_status_logging.application.success_role_arn, null)
  application_success_feedback_sample_rate = try(var.delivery_status_logging.application.success_sample_rate, null)
  application_failure_feedback_role_arn    = try(var.delivery_status_logging.application.failure_role_arn, null)
  http_success_feedback_role_arn           = try(var.delivery_status_logging.http.success_role_arn, null)
  http_success_feedback_sample_rate        = try(var.delivery_status_logging.http.success_sample_rate, null)
  http_failure_feedback_role_arn           = try(var.delivery_status_logging.http.failure_role_arn, null)
  lambda_success_feedback_role_arn         = try(var.delivery_status_logging.lambda.success_role_arn, null)
  lambda_success_feedback_sample_rate      = try(var.delivery_status_logging.lambda.success_sample_rate, null)
  lambda_failure_feedback_role_arn         = try(var.delivery_status_logging.lambda.failure_role_arn, null)
  sqs_success_feedback_role_arn            = try(var.delivery_status_logging.sqs.success_role_arn, null)
  sqs_success_feedback_sample_rate         = try(var.delivery_status_logging.sqs.success_sample_rate, null)
  sqs_failure_feedback_role_arn            = try(var.delivery_status_logging.sqs.failure_role_arn, null)
  firehose_success_feedback_role_arn       = try(var.delivery_status_logging.firehose.success_role_arn, null)
  firehose_success_feedback_sample_rate    = try(var.delivery_status_logging.firehose.success_sample_rate, null)
  firehose_failure_feedback_role_arn       = try(var.delivery_status_logging.firehose.failure_role_arn, null)

  tags = merge(
    var.tags,
    { Name = local.topic_name }
  )
}

# Topic Policy (toggle: create_topic_policy)
data "aws_iam_policy_document" "this" {
  count = var.create_topic && var.create_topic_policy ? 1 : 0

  source_policy_documents   = var.additional_policy_json_documents
  override_policy_documents = var.policy_json != null ? [var.policy_json] : []

  statement {
    sid     = "AllowAccountOwner"
    effect  = "Allow"
    actions = ["SNS:GetTopicAttributes", "SNS:SetTopicAttributes", "SNS:AddPermission", "SNS:RemovePermission", "SNS:DeleteTopic", "SNS:Subscribe", "SNS:ListSubscriptionsByTopic", "SNS:Publish"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [local.topic_arn]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  dynamic "statement" {
    for_each = length(var.publisher_service_principals) > 0 ? [1] : []

    content {
      sid     = "AllowServicePublish"
      effect  = "Allow"
      actions = ["SNS:Publish"]

      principals {
        type        = "Service"
        identifiers = var.publisher_service_principals
      }

      resources = [local.topic_arn]

      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }
    }
  }

  dynamic "statement" {
    for_each = var.enforce_secure_transport ? [1] : []

    content {
      sid     = "DenyInsecureTransport"
      effect  = "Deny"
      actions = ["SNS:Publish"]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      resources = [local.topic_arn]

      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["false"]
      }
    }
  }
}

resource "aws_sns_topic_policy" "this" {
  count = var.create_topic && var.create_topic_policy ? 1 : 0

  arn    = local.topic_arn
  policy = data.aws_iam_policy_document.this[0].json
}

# Subscriptions
resource "aws_sns_topic_subscription" "this" {
  for_each = var.create_topic ? var.subscriptions : {}

  topic_arn                       = local.topic_arn
  protocol                        = each.value.protocol
  endpoint                        = each.value.endpoint
  subscription_role_arn           = each.value.subscription_role_arn
  confirmation_timeout_in_minutes = each.value.confirmation_timeout_in_minutes
  endpoint_auto_confirms          = each.value.endpoint_auto_confirms
  delivery_policy                 = each.value.delivery_policy
  filter_policy                   = each.value.filter_policy
  filter_policy_scope             = each.value.filter_policy_scope
  raw_message_delivery            = each.value.raw_message_delivery
  redrive_policy                  = each.value.redrive_policy
  replay_policy                   = each.value.replay_policy
}
