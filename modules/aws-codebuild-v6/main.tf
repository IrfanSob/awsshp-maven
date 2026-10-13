# Reusable CodeBuild project module.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.54.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
  partition  = data.aws_partition.current.partition

  log_group_name = coalesce(var.cloudwatch_logs.group_name, "/aws/codebuild/${var.name}")

  service_role_arn = var.create_service_role ? one(aws_iam_role.this[*].arn) : var.service_role_arn
}

# CloudWatch Log Group (toggle: create_log_group)
resource "aws_cloudwatch_log_group" "this" {
  count = var.create_project && var.create_log_group && var.cloudwatch_logs.status == "ENABLED" ? 1 : 0

  name              = local.log_group_name
  retention_in_days = var.log_group_retention_in_days
  kms_key_id        = var.log_group_kms_key_id

  tags = merge(
    var.tags,
    { Name = local.log_group_name }
  )
}

# Service Role (toggle: create_service_role)
data "aws_iam_policy_document" "assume_role" {
  count = var.create_project && var.create_service_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

data "aws_iam_policy_document" "service" {
  count = var.create_project && var.create_service_role ? 1 : 0

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:${local.log_group_name}",
      "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:${local.log_group_name}:*"
    ]
  }

  statement {
    sid    = "CodeBuildReports"
    effect = "Allow"
    actions = [
      "codebuild:CreateReportGroup",
      "codebuild:CreateReport",
      "codebuild:UpdateReport",
      "codebuild:BatchPutTestCases",
      "codebuild:BatchPutCodeCoverages"
    ]
    resources = ["arn:${local.partition}:codebuild:${local.region}:${local.account_id}:report-group/${var.name}-*"]
  }

  dynamic "statement" {
    for_each = length(var.service_role_s3_bucket_arns) > 0 ? [1] : []

    content {
      sid    = "S3Access"
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject",
        "s3:GetBucketAcl",
        "s3:GetBucketLocation",
        "s3:ListBucket"
      ]
      resources = concat(
        var.service_role_s3_bucket_arns,
        [for arn in var.service_role_s3_bucket_arns : "${arn}/*"]
      )
    }
  }

  dynamic "statement" {
    for_each = length(var.service_role_ecr_repository_arns) > 0 ? [1] : []

    content {
      sid       = "EcrAuthorization"
      effect    = "Allow"
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = length(var.service_role_ecr_repository_arns) > 0 ? [1] : []

    content {
      sid    = "EcrPushPull"
      effect = "Allow"
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeImages",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ]
      resources = var.service_role_ecr_repository_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.service_role_kms_key_arns) > 0 ? [1] : []

    content {
      sid    = "KmsUse"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:Encrypt",
        "kms:GenerateDataKey*",
        "kms:ReEncrypt*"
      ]
      resources = var.service_role_kms_key_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.service_role_secret_arns) > 0 ? [1] : []

    content {
      sid       = "SecretsManagerRead"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = var.service_role_secret_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.service_role_ssm_parameter_arns) > 0 ? [1] : []

    content {
      sid       = "SsmParameterRead"
      effect    = "Allow"
      actions   = ["ssm:GetParameters"]
      resources = var.service_role_ssm_parameter_arns
    }
  }

  dynamic "statement" {
    for_each = var.vpc_config != null ? [1] : []

    content {
      sid    = "VpcNetworkInterfaces"
      effect = "Allow"
      actions = [
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs"
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = var.vpc_config != null ? [1] : []

    content {
      sid       = "VpcNetworkInterfacePermission"
      effect    = "Allow"
      actions   = ["ec2:CreateNetworkInterfacePermission"]
      resources = ["arn:${local.partition}:ec2:${local.region}:${local.account_id}:network-interface/*"]

      condition {
        test     = "StringEquals"
        variable = "ec2:AuthorizedService"
        values   = ["codebuild.amazonaws.com"]
      }

      condition {
        test     = "ArnEquals"
        variable = "ec2:Subnet"
        values   = [for s in var.vpc_config.subnets : "arn:${local.partition}:ec2:${local.region}:${local.account_id}:subnet/${s}"]
      }
    }
  }
}

resource "aws_iam_role" "this" {
  count = var.create_project && var.create_service_role ? 1 : 0

  name                 = coalesce(var.service_role_name, "${var.name}-codebuild-role")
  path                 = var.service_role_path
  permissions_boundary = var.service_role_permissions_boundary
  assume_role_policy   = data.aws_iam_policy_document.assume_role[0].json

  tags = merge(
    var.tags,
    { Name = coalesce(var.service_role_name, "${var.name}-codebuild-role") }
  )
}

resource "aws_iam_role_policy" "base" {
  count = var.create_project && var.create_service_role ? 1 : 0

  name   = "${var.name}-codebuild-base"
  role   = aws_iam_role.this[0].id
  policy = data.aws_iam_policy_document.service[0].json
}

resource "aws_iam_role_policy" "inline" {
  for_each = var.create_project && var.create_service_role ? var.service_role_inline_policies : {}

  name   = each.key
  role   = aws_iam_role.this[0].id
  policy = each.value
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = var.create_project && var.create_service_role ? toset(var.service_role_managed_policy_arns) : toset([])

  role       = aws_iam_role.this[0].name
  policy_arn = each.value
}

# CodeBuild Project
resource "aws_codebuild_project" "this" {
  count = var.create_project ? 1 : 0

  name                   = var.name
  description            = var.description
  service_role           = local.service_role_arn
  build_timeout          = var.build_timeout
  queued_timeout         = var.queued_timeout
  concurrent_build_limit = var.concurrent_build_limit
  auto_retry_limit       = var.auto_retry_limit
  badge_enabled          = var.badge_enabled
  project_visibility     = var.project_visibility
  resource_access_role   = var.resource_access_role
  encryption_key         = var.encryption_key
  source_version         = var.source_version

  source {
    type                = var.source_config.type
    location            = var.source_config.location
    buildspec           = var.source_config.buildspec
    git_clone_depth     = var.source_config.git_clone_depth
    insecure_ssl        = var.source_config.insecure_ssl
    report_build_status = var.source_config.report_build_status

    dynamic "git_submodules_config" {
      for_each = var.source_config.fetch_submodules != null ? [1] : []

      content {
        fetch_submodules = var.source_config.fetch_submodules
      }
    }

    dynamic "auth" {
      for_each = var.source_config.auth != null ? [var.source_config.auth] : []

      content {
        type     = auth.value.type
        resource = auth.value.resource
      }
    }

    dynamic "build_status_config" {
      for_each = var.source_config.build_status_config != null ? [var.source_config.build_status_config] : []

      content {
        context    = build_status_config.value.context
        target_url = build_status_config.value.target_url
      }
    }
  }

  dynamic "secondary_sources" {
    for_each = var.secondary_sources

    content {
      source_identifier   = secondary_sources.value.source_identifier
      type                = secondary_sources.value.type
      location            = secondary_sources.value.location
      buildspec           = secondary_sources.value.buildspec
      git_clone_depth     = secondary_sources.value.git_clone_depth
      insecure_ssl        = secondary_sources.value.insecure_ssl
      report_build_status = secondary_sources.value.report_build_status

      dynamic "git_submodules_config" {
        for_each = secondary_sources.value.fetch_submodules != null ? [1] : []

        content {
          fetch_submodules = secondary_sources.value.fetch_submodules
        }
      }

      dynamic "auth" {
        for_each = secondary_sources.value.auth != null ? [secondary_sources.value.auth] : []

        content {
          type     = auth.value.type
          resource = auth.value.resource
        }
      }

      dynamic "build_status_config" {
        for_each = secondary_sources.value.build_status_config != null ? [secondary_sources.value.build_status_config] : []

        content {
          context    = build_status_config.value.context
          target_url = build_status_config.value.target_url
        }
      }
    }
  }

  dynamic "secondary_source_version" {
    for_each = var.secondary_source_versions

    content {
      source_identifier = secondary_source_version.key
      source_version    = secondary_source_version.value
    }
  }

  artifacts {
    type                   = var.artifacts.type
    location               = var.artifacts.location
    name                   = var.artifacts.name
    namespace_type         = var.artifacts.namespace_type
    packaging              = var.artifacts.packaging
    path                   = var.artifacts.path
    encryption_disabled    = var.artifacts.encryption_disabled
    override_artifact_name = var.artifacts.override_artifact_name
    artifact_identifier    = var.artifacts.artifact_identifier
    bucket_owner_access    = var.artifacts.bucket_owner_access
  }

  dynamic "secondary_artifacts" {
    for_each = var.secondary_artifacts

    content {
      artifact_identifier    = secondary_artifacts.value.artifact_identifier
      type                   = secondary_artifacts.value.type
      location               = secondary_artifacts.value.location
      name                   = secondary_artifacts.value.name
      namespace_type         = secondary_artifacts.value.namespace_type
      packaging              = secondary_artifacts.value.packaging
      path                   = secondary_artifacts.value.path
      encryption_disabled    = secondary_artifacts.value.encryption_disabled
      override_artifact_name = secondary_artifacts.value.override_artifact_name
      bucket_owner_access    = secondary_artifacts.value.bucket_owner_access
    }
  }

  environment {
    compute_type                = var.environment.compute_type
    image                       = var.environment.image
    type                        = var.environment.type
    image_pull_credentials_type = var.environment.image_pull_credentials_type
    privileged_mode             = var.environment.privileged_mode
    certificate                 = var.environment.certificate
    host_kernel                 = var.environment.host_kernel

    dynamic "fleet" {
      for_each = var.environment.fleet_arn != null ? [1] : []

      content {
        fleet_arn = var.environment.fleet_arn
      }
    }

    dynamic "registry_credential" {
      for_each = var.environment.registry_credential != null ? [var.environment.registry_credential] : []

      content {
        credential          = registry_credential.value.credential
        credential_provider = registry_credential.value.credential_provider
      }
    }

    dynamic "docker_server" {
      for_each = var.environment.docker_server != null ? [var.environment.docker_server] : []

      content {
        compute_type       = docker_server.value.compute_type
        security_group_ids = docker_server.value.security_group_ids
      }
    }

    dynamic "environment_variable" {
      for_each = var.environment.environment_variables

      content {
        name  = environment_variable.value.name
        value = environment_variable.value.value
        type  = environment_variable.value.type
      }
    }
  }

  dynamic "cache" {
    for_each = var.cache != null ? [var.cache] : []

    content {
      type            = cache.value.type
      location        = cache.value.location
      modes           = cache.value.modes
      cache_namespace = cache.value.cache_namespace
    }
  }

  logs_config {
    cloudwatch_logs {
      status      = var.cloudwatch_logs.status
      group_name  = var.cloudwatch_logs.status == "ENABLED" ? local.log_group_name : null
      stream_name = var.cloudwatch_logs.stream_name
    }

    s3_logs {
      status              = var.s3_logs.status
      location            = var.s3_logs.location
      encryption_disabled = var.s3_logs.encryption_disabled
      bucket_owner_access = var.s3_logs.bucket_owner_access
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []

    content {
      vpc_id             = vpc_config.value.vpc_id
      subnets            = vpc_config.value.subnets
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  dynamic "file_system_locations" {
    for_each = var.file_system_locations

    content {
      identifier    = file_system_locations.value.identifier
      location      = file_system_locations.value.location
      mount_options = file_system_locations.value.mount_options
      mount_point   = file_system_locations.value.mount_point
      type          = file_system_locations.value.type
    }
  }

  dynamic "build_batch_config" {
    for_each = var.build_batch_config != null ? [var.build_batch_config] : []

    content {
      service_role      = build_batch_config.value.service_role
      combine_artifacts = build_batch_config.value.combine_artifacts
      timeout_in_mins   = build_batch_config.value.timeout_in_mins

      dynamic "restrictions" {
        for_each = build_batch_config.value.restrictions != null ? [build_batch_config.value.restrictions] : []

        content {
          compute_types_allowed  = restrictions.value.compute_types_allowed
          maximum_builds_allowed = restrictions.value.maximum_builds_allowed
        }
      }
    }
  }

  tags = merge(
    var.tags,
    { Name = var.name }
  )

  lifecycle {
    precondition {
      condition     = local.service_role_arn != null
      error_message = "service_role_arn is required when create_service_role is false."
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy.base
  ]
}

# Webhook (toggle: create_webhook, needs a source provider reachable from the Region)
resource "aws_codebuild_webhook" "this" {
  count = var.create_project && var.create_webhook ? 1 : 0

  project_name    = aws_codebuild_project.this[0].name
  build_type      = var.webhook_build_type
  manual_creation = var.webhook_manual_creation
  branch_filter   = var.webhook_branch_filter

  dynamic "filter_group" {
    for_each = var.webhook_filter_groups

    content {
      dynamic "filter" {
        for_each = filter_group.value

        content {
          type                    = filter.value.type
          pattern                 = filter.value.pattern
          exclude_matched_pattern = filter.value.exclude_matched_pattern
        }
      }
    }
  }

  dynamic "scope_configuration" {
    for_each = var.webhook_scope_configuration != null ? [var.webhook_scope_configuration] : []

    content {
      name   = scope_configuration.value.name
      scope  = scope_configuration.value.scope
      domain = scope_configuration.value.domain
    }
  }

  dynamic "pull_request_build_policy" {
    for_each = var.webhook_pull_request_build_policy != null ? [var.webhook_pull_request_build_policy] : []

    content {
      requires_comment_approval = pull_request_build_policy.value.requires_comment_approval
      approver_roles            = pull_request_build_policy.value.approver_roles
    }
  }
}
