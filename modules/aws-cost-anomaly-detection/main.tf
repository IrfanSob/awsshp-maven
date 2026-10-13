# Reusable AWS Cost Anomaly Detection module.
# Creates anomaly monitors, their alert subscriptions and, optionally, the SNS topic
# the alerts are published to together with the topic policy Cost Explorer needs.
#
# Monitors cover the whole account across every region, so the region this module
# runs in does not narrow what is watched. Cost Explorer publishes a single API
# endpoint in us-east-1 and the SDK routes there from any region. If a provider
# version ever rejects that, pass a us-east-1 aliased provider into this module.

data "aws_caller_identity" "current" {}

locals {
  sns_topic_arn = var.create_sns_topic ? aws_sns_topic.this[0].arn : var.existing_sns_topic_arn
}

resource "aws_sns_topic" "this" {
  count = var.create_sns_topic ? 1 : 0

  name              = var.sns_topic_name != null ? var.sns_topic_name : "${var.name_prefix}-cost-anomaly-topic"
  kms_master_key_id = var.sns_kms_master_key_id

  tags = merge(
    var.tags,
    {
      Name = var.sns_topic_name != null ? var.sns_topic_name : "${var.name_prefix}-cost-anomaly-topic"
    }
  )
}

resource "aws_sns_topic_subscription" "email" {
  for_each = var.create_sns_topic ? toset(var.sns_email_subscriptions) : []

  topic_arn = aws_sns_topic.this[0].arn
  protocol  = "email"
  endpoint  = each.value
}

# Cost Explorer publishes anomaly alerts as costalerts.amazonaws.com, which needs an
# explicit allow on the topic.
data "aws_iam_policy_document" "sns" {
  count = var.create_sns_topic ? 1 : 0

  statement {
    sid       = "AllowCostAnomalyDetectionPublish"
    effect    = "Allow"
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.this[0].arn]

    principals {
      type        = "Service"
      identifiers = ["costalerts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  dynamic "statement" {
    for_each = var.sns_topic_allow_account_owner_full_access ? [1] : []

    content {
      sid    = "AllowAccountOwnerFullAccess"
      effect = "Allow"

      actions = [
        "SNS:GetTopicAttributes",
        "SNS:SetTopicAttributes",
        "SNS:AddPermission",
        "SNS:RemovePermission",
        "SNS:DeleteTopic",
        "SNS:Subscribe",
        "SNS:ListSubscriptionsByTopic",
        "SNS:Publish"
      ]

      resources = [aws_sns_topic.this[0].arn]

      principals {
        type        = "AWS"
        identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
      }
    }
  }
}

resource "aws_sns_topic_policy" "this" {
  count = var.create_sns_topic ? 1 : 0

  arn    = aws_sns_topic.this[0].arn
  policy = data.aws_iam_policy_document.sns[0].json
}

resource "aws_ce_anomaly_monitor" "this" {
  for_each = var.monitors

  name              = each.value.name != null ? each.value.name : each.key
  monitor_type      = each.value.monitor_type
  monitor_dimension = each.value.monitor_type == "DIMENSIONAL" ? each.value.monitor_dimension : null

  # Required for CUSTOM monitors. A Cost Explorer expression in JSON that selects
  # the linked accounts, tags or cost categories the monitor watches.
  monitor_specification = each.value.monitor_type == "CUSTOM" ? each.value.monitor_specification_json : null

  tags = merge(
    var.tags,
    each.value.tags,
    {
      Name = each.value.name != null ? each.value.name : each.key
    }
  )
}

resource "aws_ce_anomaly_subscription" "this" {
  for_each = var.subscriptions

  name      = each.value.name != null ? each.value.name : each.key
  frequency = each.value.frequency

  monitor_arn_list = length(each.value.monitor_keys) > 0 ? [
    for key in each.value.monitor_keys : aws_ce_anomaly_monitor.this[key].arn
  ] : each.value.monitor_arns

  dynamic "subscriber" {
    for_each = each.value.subscriber_email_addresses

    content {
      type    = "EMAIL"
      address = subscriber.value
    }
  }

  dynamic "subscriber" {
    for_each = each.value.subscriber_sns_topic_arns

    content {
      type    = "SNS"
      address = subscriber.value
    }
  }

  # Guarded on variables, not on the topic ARN, which is unknown at plan time when
  # the topic is created in the same apply.
  dynamic "subscriber" {
    for_each = each.value.use_module_sns_topic && (var.create_sns_topic || var.existing_sns_topic_arn != null) ? [local.sns_topic_arn] : []

    content {
      type    = "SNS"
      address = subscriber.value
    }
  }

  # Anomalies below this impact do not raise an alert.
  threshold_expression {
    dimension {
      key           = each.value.threshold_key
      match_options = [each.value.threshold_match_option]
      values        = [tostring(each.value.threshold_value)]
    }
  }

  tags = merge(
    var.tags,
    each.value.tags,
    {
      Name = each.value.name != null ? each.value.name : each.key
    }
  )

  depends_on = [aws_sns_topic_policy.this]
}
