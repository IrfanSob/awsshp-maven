# Note: AWS provider v6 variant of aws-cloudtrail-management-events, using data.aws_region.region instead of the deprecated .name.
# Note: with create_s3_bucket = false the caller must depend_on the existing bucket's policy.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  trail_arn = "arn:aws:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/${var.trail_name}"

  s3_bucket_name = var.create_s3_bucket ? aws_s3_bucket.this[0].id : var.s3_bucket_name
  s3_bucket_arn  = var.create_s3_bucket ? aws_s3_bucket.this[0].arn : "arn:aws:s3:::${var.s3_bucket_name}"
  s3_key_prefix  = var.s3_key_prefix != null ? "${trimsuffix(var.s3_key_prefix, "/")}/" : ""

  cloudwatch_log_group_name = coalesce(var.cloudwatch_log_group_name, "/aws/cloudtrail/${var.trail_name}")
  cloudwatch_logs_role_name = coalesce(var.cloudwatch_logs_role_name, "${var.trail_name}-cloudwatch-logs-role")
}

# Note: keeps the state of resources created before create_s3_bucket existed.
moved {
  from = aws_s3_bucket.this
  to   = aws_s3_bucket.this[0]
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.this
  to   = aws_s3_bucket_server_side_encryption_configuration.this[0]
}

moved {
  from = aws_s3_bucket_ownership_controls.this
  to   = aws_s3_bucket_ownership_controls.this[0]
}

moved {
  from = aws_s3_bucket_public_access_block.this
  to   = aws_s3_bucket_public_access_block.this[0]
}

moved {
  from = aws_s3_bucket_policy.this
  to   = aws_s3_bucket_policy.this[0]
}

# S3 Bucket (Log Storage)
resource "aws_s3_bucket" "this" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = var.s3_bucket_name

  tags = merge(
    var.tags,
    { Name = var.s3_bucket_name }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.this[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.this[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  count = var.create_s3_bucket ? 1 : 0

  bucket                  = aws_s3_bucket.this[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket Policy (Allow CloudTrail)
data "aws_iam_policy_document" "cloudtrail_s3_policy" {
  count = var.create_s3_bucket ? 1 : 0

  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [local.s3_bucket_arn]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = ["s3:PutObject"]

    resources = [
      "${local.s3_bucket_arn}/${local.s3_key_prefix}AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [local.trail_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.this[0].id
  policy = data.aws_iam_policy_document.cloudtrail_s3_policy[0].json
}

# CloudWatch Logs delivery (optional)
resource "aws_cloudwatch_log_group" "this" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name              = local.cloudwatch_log_group_name
  retention_in_days = var.cloudwatch_log_retention_in_days
  kms_key_id        = var.cloudwatch_log_kms_key_arn

  tags = merge(
    var.tags,
    { Name = local.cloudwatch_log_group_name }
  )
}

data "aws_iam_policy_document" "cloudwatch_logs_assume_role" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "cloudwatch_logs_delivery" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  statement {
    sid       = "AWSCloudTrailCreateLogStream"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this[0].arn}:log-stream:*"]
  }
}

resource "aws_iam_role" "cloudwatch_logs" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name               = local.cloudwatch_logs_role_name
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_logs_assume_role[0].json

  tags = merge(
    var.tags,
    { Name = local.cloudwatch_logs_role_name }
  )
}

resource "aws_iam_role_policy" "cloudwatch_logs" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name   = "cloudtrail-cloudwatch-logs-delivery"
  role   = aws_iam_role.cloudwatch_logs[0].id
  policy = data.aws_iam_policy_document.cloudwatch_logs_delivery[0].json
}

# CloudTrail Management Event Trail
resource "aws_cloudtrail" "this" {
  name                          = var.trail_name
  s3_bucket_name                = local.s3_bucket_name
  s3_key_prefix                 = var.s3_key_prefix != null ? trimsuffix(var.s3_key_prefix, "/") : null
  kms_key_id                    = var.kms_key_arn
  include_global_service_events = true
  is_multi_region_trail         = var.is_multi_region_trail
  enable_log_file_validation    = var.enable_log_file_validation
  enable_logging                = true

  cloud_watch_logs_group_arn = var.enable_cloudwatch_logs ? "${aws_cloudwatch_log_group.this[0].arn}:*" : null
  cloud_watch_logs_role_arn  = var.enable_cloudwatch_logs ? aws_iam_role.cloudwatch_logs[0].arn : null

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = merge(
    var.tags,
    { "Name" = var.trail_name }
  )

  depends_on = [
    aws_s3_bucket_policy.this,
    aws_s3_bucket_ownership_controls.this,
    aws_iam_role_policy.cloudwatch_logs
  ]
}
