# Reusable S3 bucket module.
# Every capability is optional and driven by a flag, so the same module can back a
# log bucket, an application data bucket, a static website or a replication target.

data "aws_caller_identity" "current" {}

locals {
  bucket_id  = one(aws_s3_bucket.this[*].id)
  bucket_arn = one(aws_s3_bucket.this[*].arn)

  # Accounts whose logs this bucket accepts. Defaults to the account holding the bucket.
  log_delivery_account_ids = length(var.log_delivery_source_account_ids) > 0 ? var.log_delivery_source_account_ids : [data.aws_caller_identity.current.account_id]

  # A bucket policy is attached only when one is supplied or at least one policy
  # flag is on, so a plain bucket is left without a policy.
  attach_policy = var.create_bucket && (
    var.bucket_policy_json != null ||
    var.attach_deny_insecure_transport_policy ||
    var.attach_deny_unencrypted_object_upload_policy ||
    var.attach_lb_log_delivery_policy ||
    var.attach_s3_access_log_delivery_policy ||
    var.attach_delivery_logs_policy ||
    var.attach_cloudtrail_log_delivery_policy ||
    length(var.additional_policy_json_documents) > 0
  )

  # S3 accepts a single criterion directly on the filter, but two or more must be
  # wrapped in an "and" block. Count the criteria per rule so the filter below can
  # pick the right shape.
  lifecycle_rules = [
    for rule in var.lifecycle_rules : merge(rule, {
      filter_criteria_count = (
        (try(rule.filter.prefix, null) != null ? 1 : 0) +
        length(coalesce(try(rule.filter.tags, {}), {})) +
        (try(rule.filter.object_size_greater_than, null) != null ? 1 : 0) +
        (try(rule.filter.object_size_less_than, null) != null ? 1 : 0)
      )
    })
  ]
}

resource "aws_s3_bucket" "this" {
  count = var.create_bucket ? 1 : 0

  bucket              = var.bucket_name
  bucket_prefix       = var.bucket_prefix
  force_destroy       = var.force_destroy
  object_lock_enabled = var.object_lock_enabled

  tags = merge(
    var.tags,
    {
      Name = coalesce(var.bucket_name, var.bucket_prefix)
    }
  )
}

resource "aws_s3_bucket_ownership_controls" "this" {
  count = var.create_bucket && var.object_ownership != null ? 1 : 0

  bucket = local.bucket_id

  rule {
    object_ownership = var.object_ownership
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  count = var.create_bucket && var.enable_public_access_block ? 1 : 0

  bucket = local.bucket_id

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

# An ACL can only be set when object ownership still honours ACLs, so this stays
# off unless the caller explicitly asks for one.
resource "aws_s3_bucket_acl" "this" {
  count = var.create_bucket && var.acl != null ? 1 : 0

  bucket = local.bucket_id
  acl    = var.acl

  depends_on = [
    aws_s3_bucket_ownership_controls.this,
    aws_s3_bucket_public_access_block.this
  ]
}

resource "aws_s3_bucket_versioning" "this" {
  count = var.create_bucket && var.versioning_status != null ? 1 : 0

  bucket = local.bucket_id
  mfa    = var.versioning_mfa

  versioning_configuration {
    status     = var.versioning_status
    mfa_delete = var.versioning_mfa_delete
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count = var.create_bucket && var.enable_server_side_encryption ? 1 : 0

  bucket = local.bucket_id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm
      kms_master_key_id = var.sse_algorithm == "aws:kms" ? var.kms_key_arn : null
    }

    bucket_key_enabled = var.bucket_key_enabled
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = var.create_bucket && length(var.lifecycle_rules) > 0 ? 1 : 0

  bucket = local.bucket_id

  dynamic "rule" {
    for_each = local.lifecycle_rules

    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      # Always rendered. With no criteria this is an empty filter, which scopes the
      # rule to every object in the bucket.
      filter {
        prefix = rule.value.filter_criteria_count == 1 ? try(rule.value.filter.prefix, null) : null

        object_size_greater_than = rule.value.filter_criteria_count == 1 ? try(rule.value.filter.object_size_greater_than, null) : null
        object_size_less_than    = rule.value.filter_criteria_count == 1 ? try(rule.value.filter.object_size_less_than, null) : null

        dynamic "tag" {
          for_each = rule.value.filter_criteria_count == 1 ? coalesce(try(rule.value.filter.tags, {}), {}) : {}

          content {
            key   = tag.key
            value = tag.value
          }
        }

        dynamic "and" {
          for_each = rule.value.filter_criteria_count > 1 ? [rule.value.filter] : []

          content {
            prefix                   = and.value.prefix
            tags                     = length(coalesce(and.value.tags, {})) > 0 ? and.value.tags : null
            object_size_greater_than = and.value.object_size_greater_than
            object_size_less_than    = and.value.object_size_less_than
          }
        }
      }

      dynamic "transition" {
        for_each = coalesce(rule.value.transitions, [])

        content {
          days          = transition.value.days
          date          = transition.value.date
          storage_class = transition.value.storage_class
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration != null ? [rule.value.expiration] : []

        content {
          days                         = expiration.value.days
          date                         = expiration.value.date
          expired_object_delete_marker = expiration.value.expired_object_delete_marker
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = coalesce(rule.value.noncurrent_version_transitions, [])

        content {
          noncurrent_days           = noncurrent_version_transition.value.noncurrent_days
          newer_noncurrent_versions = noncurrent_version_transition.value.newer_noncurrent_versions
          storage_class             = noncurrent_version_transition.value.storage_class
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration != null ? [rule.value.noncurrent_version_expiration] : []

        content {
          noncurrent_days           = noncurrent_version_expiration.value.noncurrent_days
          newer_noncurrent_versions = noncurrent_version_expiration.value.newer_noncurrent_versions
        }
      }

      dynamic "abort_incomplete_multipart_upload" {
        for_each = rule.value.abort_incomplete_multipart_upload_days != null ? [1] : []

        content {
          days_after_initiation = rule.value.abort_incomplete_multipart_upload_days
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_logging" "this" {
  count = var.create_bucket && var.logging != null ? 1 : 0

  bucket        = local.bucket_id
  target_bucket = var.logging.target_bucket
  target_prefix = var.logging.target_prefix
}

resource "aws_s3_bucket_cors_configuration" "this" {
  count = var.create_bucket && length(var.cors_rules) > 0 ? 1 : 0

  bucket = local.bucket_id

  dynamic "cors_rule" {
    for_each = var.cors_rules

    content {
      id              = cors_rule.value.id
      allowed_headers = cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

resource "aws_s3_bucket_website_configuration" "this" {
  count = var.create_bucket && var.website != null ? 1 : 0

  bucket = local.bucket_id

  dynamic "index_document" {
    for_each = var.website.index_document != null ? [1] : []

    content {
      suffix = var.website.index_document
    }
  }

  dynamic "error_document" {
    for_each = var.website.error_document != null ? [1] : []

    content {
      key = var.website.error_document
    }
  }

  dynamic "redirect_all_requests_to" {
    for_each = var.website.redirect_all_requests_to != null ? [1] : []

    content {
      host_name = var.website.redirect_all_requests_to
      protocol  = var.website.redirect_protocol
    }
  }
}

# Object lock retention. The bucket itself must have been created with
# object_lock_enabled, which cannot be turned on afterwards.
resource "aws_s3_bucket_object_lock_configuration" "this" {
  count = var.create_bucket && var.object_lock_enabled && var.object_lock_rule != null ? 1 : 0

  bucket = local.bucket_id

  rule {
    default_retention {
      mode  = var.object_lock_rule.mode
      days  = var.object_lock_rule.days
      years = var.object_lock_rule.years
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

data "aws_iam_policy_document" "this" {
  count = local.attach_policy && var.bucket_policy_json == null ? 1 : 0

  source_policy_documents = var.additional_policy_json_documents

  dynamic "statement" {
    for_each = var.attach_deny_insecure_transport_policy ? [1] : []

    content {
      sid       = "DenyInsecureTransport"
      effect    = "Deny"
      actions   = ["s3:*"]
      resources = [local.bucket_arn, "${local.bucket_arn}/*"]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["false"]
      }
    }
  }

  dynamic "statement" {
    for_each = var.attach_deny_unencrypted_object_upload_policy ? [1] : []

    content {
      sid       = "DenyUnencryptedObjectUploads"
      effect    = "Deny"
      actions   = ["s3:PutObject"]
      resources = ["${local.bucket_arn}/*"]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "Null"
        variable = "s3:x-amz-server-side-encryption"
        values   = ["true"]
      }
    }
  }

  # Load balancer access logs. Regions launched from 2022 onward deliver through a
  # service principal, older regions through a regional ELB account.
  dynamic "statement" {
    for_each = var.attach_lb_log_delivery_policy ? [1] : []

    content {
      sid       = "AllowLoadBalancerLogDelivery"
      effect    = "Allow"
      actions   = ["s3:PutObject"]
      resources = [for id in local.log_delivery_account_ids : "${local.bucket_arn}/${var.log_delivery_prefix}AWSLogs/${id}/*"]

      dynamic "principals" {
        for_each = var.lb_log_delivery_principal_type == "service" ? [1] : []

        content {
          type        = "Service"
          identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
        }
      }

      dynamic "principals" {
        for_each = var.lb_log_delivery_principal_type == "account" ? [1] : []

        content {
          type        = "AWS"
          identifiers = [for id in var.lb_log_delivery_account_ids : "arn:aws:iam::${id}:root"]
        }
      }
    }
  }

  dynamic "statement" {
    for_each = var.attach_lb_log_delivery_policy ? [1] : []

    content {
      sid       = "AllowLoadBalancerLogDeliveryAclCheck"
      effect    = "Allow"
      actions   = ["s3:GetBucketAcl"]
      resources = [local.bucket_arn]

      dynamic "principals" {
        for_each = var.lb_log_delivery_principal_type == "service" ? [1] : []

        content {
          type        = "Service"
          identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
        }
      }

      dynamic "principals" {
        for_each = var.lb_log_delivery_principal_type == "account" ? [1] : []

        content {
          type        = "AWS"
          identifiers = [for id in var.lb_log_delivery_account_ids : "arn:aws:iam::${id}:root"]
        }
      }
    }
  }

  # S3 server access logging from other buckets in the same account.
  dynamic "statement" {
    for_each = var.attach_s3_access_log_delivery_policy ? [1] : []

    content {
      sid       = "AllowS3ServerAccessLogDelivery"
      effect    = "Allow"
      actions   = ["s3:PutObject"]
      resources = ["${local.bucket_arn}/*"]

      principals {
        type        = "Service"
        identifiers = ["logging.s3.amazonaws.com"]
      }

      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = local.log_delivery_account_ids
      }
    }
  }

  # VPC flow logs, ELB connection logs and other services that deliver through
  # delivery.logs.amazonaws.com.
  dynamic "statement" {
    for_each = var.attach_delivery_logs_policy ? [1] : []

    content {
      sid       = "AllowDeliveryLogsWrite"
      effect    = "Allow"
      actions   = ["s3:PutObject"]
      resources = ["${local.bucket_arn}/*"]

      principals {
        type        = "Service"
        identifiers = ["delivery.logs.amazonaws.com"]
      }

      condition {
        test     = "StringEquals"
        variable = "s3:x-amz-acl"
        values   = ["bucket-owner-full-control"]
      }

      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = local.log_delivery_account_ids
      }
    }
  }

  dynamic "statement" {
    for_each = var.attach_delivery_logs_policy ? [1] : []

    content {
      sid       = "AllowDeliveryLogsAclCheck"
      effect    = "Allow"
      actions   = ["s3:GetBucketAcl"]
      resources = [local.bucket_arn]

      principals {
        type        = "Service"
        identifiers = ["delivery.logs.amazonaws.com"]
      }

      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = local.log_delivery_account_ids
      }
    }
  }

  # CloudTrail delivery into a bucket the trail does not own.
  dynamic "statement" {
    for_each = var.attach_cloudtrail_log_delivery_policy ? [1] : []

    content {
      sid       = "AWSCloudTrailAclCheck"
      effect    = "Allow"
      actions   = ["s3:GetBucketAcl"]
      resources = [local.bucket_arn]

      principals {
        type        = "Service"
        identifiers = ["cloudtrail.amazonaws.com"]
      }

      dynamic "condition" {
        for_each = length(var.cloudtrail_source_arns) > 0 ? [1] : []

        content {
          test     = "StringEquals"
          variable = "aws:SourceArn"
          values   = var.cloudtrail_source_arns
        }
      }

      dynamic "condition" {
        for_each = length(var.cloudtrail_source_arns) == 0 ? [1] : []

        content {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values   = local.log_delivery_account_ids
        }
      }
    }
  }

  dynamic "statement" {
    for_each = var.attach_cloudtrail_log_delivery_policy ? [1] : []

    content {
      sid       = "AWSCloudTrailWrite"
      effect    = "Allow"
      actions   = ["s3:PutObject"]
      resources = [for id in local.log_delivery_account_ids : "${local.bucket_arn}/${var.cloudtrail_log_prefix}AWSLogs/${id}/*"]

      principals {
        type        = "Service"
        identifiers = ["cloudtrail.amazonaws.com"]
      }

      condition {
        test     = "StringEquals"
        variable = "s3:x-amz-acl"
        values   = ["bucket-owner-full-control"]
      }

      dynamic "condition" {
        for_each = length(var.cloudtrail_source_arns) > 0 ? [1] : []

        content {
          test     = "StringEquals"
          variable = "aws:SourceArn"
          values   = var.cloudtrail_source_arns
        }
      }

      dynamic "condition" {
        for_each = length(var.cloudtrail_source_arns) == 0 ? [1] : []

        content {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values   = local.log_delivery_account_ids
        }
      }
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  count = local.attach_policy ? 1 : 0

  bucket = local.bucket_id
  policy = var.bucket_policy_json != null ? var.bucket_policy_json : data.aws_iam_policy_document.this[0].json

  depends_on = [aws_s3_bucket_public_access_block.this]
}
