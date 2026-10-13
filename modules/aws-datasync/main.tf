terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Reusable AWS DataSync module.
# Creates locations (S3, NFS, SMB, EFS), the IAM roles S3 locations need, agents and
# transfer tasks with their schedules and filters. Tasks refer to locations by a
# composite key of "<type>.<location key>", for example "s3.source" or "nfs.onprem",
# or by a raw ARN for a location that already exists.

data "aws_caller_identity" "current" {}

locals {
  s3_role_locations = {
    for key, location in var.s3_locations : key => location
    if location.create_iam_role
  }

  location_arns = merge(
    { for key, location in aws_datasync_location_s3.this : "s3.${key}" => location.arn },
    { for key, location in aws_datasync_location_nfs.this : "nfs.${key}" => location.arn },
    { for key, location in aws_datasync_location_smb.this : "smb.${key}" => location.arn },
    { for key, location in aws_datasync_location_efs.this : "efs.${key}" => location.arn }
  )

  tasks = {
    for key, task in var.tasks : key => merge(task, {
      resolved_source_arn      = task.source_location_arn != null ? task.source_location_arn : local.location_arns[task.source_location_key]
      resolved_destination_arn = task.destination_location_arn != null ? task.destination_location_arn : local.location_arns[task.destination_location_key]
    })
  }

  log_group_tasks = {
    for key, task in var.tasks : key => task
    if task.create_cloudwatch_log_group
  }

  # Resolved log group name per task. DataSync requires that ENHANCED mode tasks
  # log to the literal group "/aws/datasync" -- CreateTask rejects any other name
  # with "Invalid CloudWatch log group name". BASIC mode tasks keep a group of
  # their own so their logs stay separable.
  task_log_group_names = {
    for key, task in local.log_group_tasks : key => (
      task.cloudwatch_log_group_name != null
      ? task.cloudwatch_log_group_name
      : task.task_mode == "ENHANCED"
      ? "/aws/datasync"
      : "/aws/datasync/${var.name_prefix}-${key}"
    )
  }

  # One log group per distinct name: several tasks legitimately share a group.
  # Retention and KMS settings come from the first task that resolves to the
  # name, so tasks sharing a group should declare them consistently.
  log_groups = {
    for name in distinct(values(local.task_log_group_names)) :
    name => local.log_group_tasks[
      [for key, group_name in local.task_log_group_names : key if group_name == name][0]
    ]
  }
}

# --- IAM for S3 locations ---------------------------------------------------------

data "aws_iam_policy_document" "datasync_assume_role" {
  count = length(local.s3_role_locations) > 0 ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["datasync.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

data "aws_iam_policy_document" "s3_access" {
  for_each = local.s3_role_locations

  statement {
    sid    = "BucketLevelAccess"
    effect = "Allow"

    actions = compact([
      "s3:GetBucketLocation",
      "s3:ListBucket",
      each.value.access_mode == "read" ? "" : "s3:ListBucketMultipartUploads"
    ])

    resources = [each.value.s3_bucket_arn]
  }

  statement {
    sid    = "ObjectLevelAccess"
    effect = "Allow"

    actions = each.value.access_mode == "read" ? [
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:GetObjectVersion",
      "s3:GetObjectVersionTagging",
      "s3:ListMultipartUploadParts"
      ] : [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:GetObjectVersion",
      "s3:GetObjectVersionTagging",
      "s3:ListMultipartUploadParts",
      "s3:PutObject",
      "s3:PutObjectTagging"
    ]

    resources = ["${each.value.s3_bucket_arn}/*"]
  }

  dynamic "statement" {
    for_each = each.value.kms_key_arns

    content {
      sid    = "KmsAccess${index(each.value.kms_key_arns, statement.value)}"
      effect = "Allow"

      actions = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey"
      ]

      resources = [statement.value]
    }
  }
}

resource "aws_iam_role" "s3" {
  for_each = local.s3_role_locations

  name               = each.value.iam_role_name != null ? each.value.iam_role_name : "${var.name_prefix}-datasync-s3-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.datasync_assume_role[0].json

  tags = merge(
    var.tags,
    {
      Name = each.value.iam_role_name != null ? each.value.iam_role_name : "${var.name_prefix}-datasync-s3-${each.key}"
    }
  )
}

resource "aws_iam_role_policy" "s3" {
  for_each = local.s3_role_locations

  name   = "datasync-s3-access"
  role   = aws_iam_role.s3[each.key].id
  policy = data.aws_iam_policy_document.s3_access[each.key].json
}

# --- Agents -----------------------------------------------------------------------

resource "aws_datasync_agent" "this" {
  for_each = var.agents

  name                  = each.value.name != null ? each.value.name : each.key
  activation_key        = each.value.activation_key
  ip_address            = each.value.ip_address
  private_link_endpoint = each.value.private_link_endpoint
  security_group_arns   = each.value.security_group_arns
  subnet_arns           = each.value.subnet_arns
  vpc_endpoint_id       = each.value.vpc_endpoint_id

  tags = merge(
    var.tags,
    each.value.tags,
    {
      Name = each.value.name != null ? each.value.name : each.key
    }
  )
}

# --- Locations --------------------------------------------------------------------

resource "aws_datasync_location_s3" "this" {
  for_each = var.s3_locations

  s3_bucket_arn    = each.value.s3_bucket_arn
  subdirectory     = each.value.subdirectory
  s3_storage_class = each.value.s3_storage_class
  agent_arns       = length(each.value.agent_keys) > 0 ? [for key in each.value.agent_keys : aws_datasync_agent.this[key].arn] : each.value.agent_arns

  s3_config {
    bucket_access_role_arn = each.value.create_iam_role ? aws_iam_role.s3[each.key].arn : each.value.iam_role_arn
  }

  tags = merge(
    var.tags,
    each.value.tags,
    {
      Name = "${var.name_prefix}-s3-${each.key}"
    }
  )

  depends_on = [aws_iam_role_policy.s3]
}

resource "aws_datasync_location_nfs" "this" {
  for_each = var.nfs_locations

  server_hostname = each.value.server_hostname
  subdirectory    = each.value.subdirectory

  on_prem_config {
    agent_arns = length(each.value.agent_keys) > 0 ? [for key in each.value.agent_keys : aws_datasync_agent.this[key].arn] : each.value.agent_arns
  }

  dynamic "mount_options" {
    for_each = each.value.nfs_version != null ? [1] : []

    content {
      version = each.value.nfs_version
    }
  }

  tags = merge(
    var.tags,
    each.value.tags,
    {
      Name = "${var.name_prefix}-nfs-${each.key}"
    }
  )
}

# smb_locations is sensitive as a whole because it carries passwords, and Terraform
# refuses a sensitive value as for_each -- the keys would leak into resource
# instance addresses. The keys themselves are just labels the caller chose, so
# iterate over those and look the record up by key. The password stays sensitive.
resource "aws_datasync_location_smb" "this" {
  for_each = toset(nonsensitive(keys(var.smb_locations)))

  server_hostname = var.smb_locations[each.key].server_hostname
  subdirectory    = var.smb_locations[each.key].subdirectory
  user            = var.smb_locations[each.key].user
  password        = var.smb_locations[each.key].password
  domain          = var.smb_locations[each.key].domain
  agent_arns = length(var.smb_locations[each.key].agent_keys) > 0 ? [
    for key in var.smb_locations[each.key].agent_keys : aws_datasync_agent.this[key].arn
  ] : var.smb_locations[each.key].agent_arns

  dynamic "mount_options" {
    for_each = var.smb_locations[each.key].smb_version != null ? [1] : []

    content {
      version = var.smb_locations[each.key].smb_version
    }
  }

  tags = merge(
    var.tags,
    var.smb_locations[each.key].tags,
    {
      Name = "${var.name_prefix}-smb-${each.key}"
    }
  )
}

resource "aws_datasync_location_efs" "this" {
  for_each = var.efs_locations

  efs_file_system_arn         = each.value.efs_file_system_arn
  subdirectory                = each.value.subdirectory
  access_point_arn            = each.value.access_point_arn
  file_system_access_role_arn = each.value.file_system_access_role_arn
  in_transit_encryption       = each.value.in_transit_encryption

  ec2_config {
    security_group_arns = each.value.security_group_arns
    subnet_arn          = each.value.subnet_arn
  }

  tags = merge(
    var.tags,
    each.value.tags,
    {
      Name = "${var.name_prefix}-efs-${each.key}"
    }
  )
}

# --- Tasks ------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "tasks" {
  for_each = local.log_groups

  name              = each.key
  retention_in_days = each.value.cloudwatch_log_retention_in_days
  kms_key_id        = each.value.cloudwatch_log_group_kms_key_id

  tags = merge(
    var.tags,
    {
      Name = each.key
    }
  )
}

# DataSync writes into the log group through a resource policy on the log group
# itself rather than through a role.
data "aws_iam_policy_document" "log_group" {
  count = length(local.log_group_tasks) > 0 ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream"
    ]

    resources = [for key, group in aws_cloudwatch_log_group.tasks : "${group.arn}:*"]

    principals {
      type        = "Service"
      identifiers = ["datasync.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "this" {
  count = length(local.log_group_tasks) > 0 ? 1 : 0

  policy_name     = "${var.name_prefix}-datasync-logs"
  policy_document = data.aws_iam_policy_document.log_group[0].json
}

resource "aws_datasync_task" "this" {
  for_each = local.tasks

  name                     = each.value.name != null ? each.value.name : "${var.name_prefix}-${each.key}"
  source_location_arn      = each.value.resolved_source_arn
  destination_location_arn = each.value.resolved_destination_arn

  cloudwatch_log_group_arn = each.value.create_cloudwatch_log_group ? aws_cloudwatch_log_group.tasks[local.task_log_group_names[each.key]].arn : each.value.cloudwatch_log_group_arn

  task_mode = each.value.task_mode

  dynamic "schedule" {
    for_each = each.value.schedule_expression != null ? [1] : []

    content {
      schedule_expression = each.value.schedule_expression
    }
  }

  dynamic "options" {
    for_each = each.value.options != null ? [each.value.options] : []

    content {
      atime                          = options.value.atime
      mtime                          = options.value.mtime
      uid                            = options.value.uid
      gid                            = options.value.gid
      bytes_per_second               = options.value.bytes_per_second
      log_level                      = options.value.log_level
      overwrite_mode                 = options.value.overwrite_mode
      posix_permissions              = options.value.posix_permissions
      preserve_deleted_files         = options.value.preserve_deleted_files
      preserve_devices               = options.value.preserve_devices
      security_descriptor_copy_flags = options.value.security_descriptor_copy_flags
      task_queueing                  = options.value.task_queueing
      transfer_mode                  = options.value.transfer_mode
      verify_mode                    = options.value.verify_mode
      object_tags                    = options.value.object_tags
    }
  }

  dynamic "includes" {
    for_each = each.value.includes != null ? [each.value.includes] : []

    content {
      filter_type = includes.value.filter_type
      value       = includes.value.value
    }
  }

  dynamic "excludes" {
    for_each = each.value.excludes != null ? [each.value.excludes] : []

    content {
      filter_type = excludes.value.filter_type
      value       = excludes.value.value
    }
  }

  tags = merge(
    var.tags,
    each.value.tags,
    {
      Name = each.value.name != null ? each.value.name : "${var.name_prefix}-${each.key}"
    }
  )

  depends_on = [aws_cloudwatch_log_resource_policy.this]
}
