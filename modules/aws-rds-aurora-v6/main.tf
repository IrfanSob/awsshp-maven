# Reusable Aurora (RDS cluster) module.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.54.0"
    }
  }
}

data "aws_partition" "current" {}

locals {
  is_multi_az_db_cluster = contains(["mysql", "postgres"], var.engine)

  db_subnet_group_name = (
    var.create_db_subnet_group
    ? one(aws_db_subnet_group.this[*].name)
    : var.existing_db_subnet_group_name
  )

  cluster_parameter_group_name = (
    var.create_cluster_parameter_group
    ? one(aws_rds_cluster_parameter_group.this[*].name)
    : var.existing_cluster_parameter_group_name
  )

  db_parameter_group_name = (
    var.create_db_parameter_group
    ? one(aws_db_parameter_group.this[*].name)
    : var.existing_db_parameter_group_name
  )

  monitoring_role_arn = (
    var.create_monitoring_role
    ? one(aws_iam_role.monitoring[*].arn)
    : var.monitoring_role_arn
  )

  final_snapshot_identifier = coalesce(var.final_snapshot_identifier, "${var.cluster_identifier}-final-snapshot")
}

# DB Subnet Group
resource "aws_db_subnet_group" "this" {
  count = var.create_cluster && var.create_db_subnet_group ? 1 : 0

  name        = coalesce(var.db_subnet_group_name, "${var.cluster_identifier}-subnet-group")
  description = var.db_subnet_group_description
  subnet_ids  = var.subnet_ids

  tags = merge(
    var.tags,
    { Name = coalesce(var.db_subnet_group_name, "${var.cluster_identifier}-subnet-group") }
  )

  lifecycle {
    precondition {
      condition     = length(var.subnet_ids) > 0
      error_message = "subnet_ids must not be empty when create_db_subnet_group is true."
    }
  }
}

# Cluster Parameter Group
resource "aws_rds_cluster_parameter_group" "this" {
  count = var.create_cluster && var.create_cluster_parameter_group ? 1 : 0

  name        = coalesce(var.cluster_parameter_group_name, "${var.cluster_identifier}-cluster-pg")
  family      = var.cluster_parameter_group_family
  description = var.cluster_parameter_group_description

  dynamic "parameter" {
    for_each = var.cluster_parameters

    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = merge(
    var.tags,
    { Name = coalesce(var.cluster_parameter_group_name, "${var.cluster_identifier}-cluster-pg") }
  )

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = var.cluster_parameter_group_family != null
      error_message = "cluster_parameter_group_family is required when create_cluster_parameter_group is true (e.g. aurora-postgresql16)."
    }
  }
}

# DB (Instance) Parameter Group
resource "aws_db_parameter_group" "this" {
  count = var.create_cluster && var.create_db_parameter_group ? 1 : 0

  name         = coalesce(var.db_parameter_group_name, "${var.cluster_identifier}-instance-pg")
  family       = var.db_parameter_group_family
  description  = var.db_parameter_group_description
  skip_destroy = var.db_parameter_group_skip_destroy

  dynamic "parameter" {
    for_each = var.db_parameters

    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = merge(
    var.tags,
    { Name = coalesce(var.db_parameter_group_name, "${var.cluster_identifier}-instance-pg") }
  )

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = var.db_parameter_group_family != null
      error_message = "db_parameter_group_family is required when create_db_parameter_group is true (e.g. aurora-postgresql16)."
    }
  }
}

# Enhanced Monitoring Role (toggle: create_monitoring_role)
data "aws_iam_policy_document" "monitoring_assume_role" {
  count = var.create_cluster && var.create_monitoring_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  count = var.create_cluster && var.create_monitoring_role ? 1 : 0

  name               = coalesce(var.monitoring_role_name, "${var.cluster_identifier}-rds-monitoring-role")
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume_role[0].json

  tags = merge(
    var.tags,
    { Name = coalesce(var.monitoring_role_name, "${var.cluster_identifier}-rds-monitoring-role") }
  )
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  count = var.create_cluster && var.create_monitoring_role ? 1 : 0

  role       = aws_iam_role.monitoring[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Log Groups for exported logs (toggle: create_cloudwatch_log_groups)
resource "aws_cloudwatch_log_group" "this" {
  for_each = var.create_cluster && var.create_cloudwatch_log_groups ? toset(var.enabled_cloudwatch_logs_exports) : toset([])

  name              = "/aws/rds/cluster/${var.cluster_identifier}/${each.value}"
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  kms_key_id        = var.cloudwatch_log_group_kms_key_id
  log_group_class   = var.cloudwatch_log_group_class

  tags = merge(
    var.tags,
    { Name = "/aws/rds/cluster/${var.cluster_identifier}/${each.value}" }
  )
}

# Aurora Cluster
resource "aws_rds_cluster" "this" {
  count = var.create_cluster ? 1 : 0

  cluster_identifier       = var.cluster_identifier
  engine                   = var.engine
  engine_version           = var.engine_version
  engine_mode              = var.engine_mode
  engine_lifecycle_support = var.engine_lifecycle_support
  cluster_scalability_type = var.cluster_scalability_type
  database_name            = var.database_name
  port                     = var.port

  master_username                     = var.master_username
  manage_master_user_password         = var.manage_master_user_password ? true : null
  master_user_secret_kms_key_id       = var.manage_master_user_password ? var.master_user_secret_kms_key_id : null
  master_password                     = var.manage_master_user_password ? null : var.master_password
  iam_database_authentication_enabled = var.iam_database_authentication_enabled
  iam_roles                           = var.iam_roles

  db_subnet_group_name      = local.db_subnet_group_name
  vpc_security_group_ids    = var.vpc_security_group_ids
  availability_zones        = var.availability_zones
  network_type              = var.network_type
  ca_certificate_identifier = var.ca_certificate_identifier

  storage_encrypted         = var.storage_encrypted
  kms_key_id                = var.kms_key_id
  storage_type              = var.storage_type
  allocated_storage         = var.allocated_storage
  iops                      = var.iops
  db_cluster_instance_class = var.db_cluster_instance_class

  db_cluster_parameter_group_name  = local.cluster_parameter_group_name
  db_instance_parameter_group_name = var.allow_major_version_upgrade ? var.db_instance_parameter_group_name : null

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window
  copy_tags_to_snapshot        = var.copy_tags_to_snapshot
  backtrack_window             = var.backtrack_window
  skip_final_snapshot          = var.skip_final_snapshot
  final_snapshot_identifier    = var.skip_final_snapshot ? null : local.final_snapshot_identifier
  delete_automated_backups     = var.delete_automated_backups
  deletion_protection          = var.deletion_protection
  snapshot_identifier          = var.snapshot_identifier

  apply_immediately           = var.apply_immediately
  allow_major_version_upgrade = var.allow_major_version_upgrade
  auto_minor_version_upgrade  = var.auto_minor_version_upgrade

  enabled_cloudwatch_logs_exports       = var.enabled_cloudwatch_logs_exports
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled ? var.performance_insights_kms_key_id : null
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  database_insights_mode                = var.database_insights_mode
  monitoring_interval                   = local.is_multi_az_db_cluster ? var.monitoring_interval : null
  monitoring_role_arn                   = local.is_multi_az_db_cluster && var.monitoring_interval > 0 ? local.monitoring_role_arn : null

  enable_http_endpoint           = var.enable_http_endpoint
  enable_global_write_forwarding = var.enable_global_write_forwarding
  enable_local_write_forwarding  = var.enable_local_write_forwarding
  global_cluster_identifier      = var.global_cluster_identifier
  replication_source_identifier  = var.replication_source_identifier
  source_region                  = var.source_region
  domain                         = var.domain
  domain_iam_role_name           = var.domain_iam_role_name
  db_system_id                   = var.db_system_id

  dynamic "serverlessv2_scaling_configuration" {
    for_each = var.serverlessv2_scaling_configuration != null ? [var.serverlessv2_scaling_configuration] : []

    content {
      min_capacity             = serverlessv2_scaling_configuration.value.min_capacity
      max_capacity             = serverlessv2_scaling_configuration.value.max_capacity
      seconds_until_auto_pause = serverlessv2_scaling_configuration.value.seconds_until_auto_pause
    }
  }

  dynamic "scaling_configuration" {
    for_each = var.scaling_configuration != null ? [var.scaling_configuration] : []

    content {
      auto_pause               = scaling_configuration.value.auto_pause
      min_capacity             = scaling_configuration.value.min_capacity
      max_capacity             = scaling_configuration.value.max_capacity
      seconds_before_timeout   = scaling_configuration.value.seconds_before_timeout
      seconds_until_auto_pause = scaling_configuration.value.seconds_until_auto_pause
      timeout_action           = scaling_configuration.value.timeout_action
    }
  }

  dynamic "restore_to_point_in_time" {
    for_each = var.restore_to_point_in_time != null ? [var.restore_to_point_in_time] : []

    content {
      restore_to_time            = restore_to_point_in_time.value.restore_to_time
      restore_type               = restore_to_point_in_time.value.restore_type
      source_cluster_identifier  = restore_to_point_in_time.value.source_cluster_identifier
      source_cluster_resource_id = restore_to_point_in_time.value.source_cluster_resource_id
      use_latest_restorable_time = restore_to_point_in_time.value.use_latest_restorable_time
    }
  }

  dynamic "s3_import" {
    for_each = var.s3_import != null ? [var.s3_import] : []

    content {
      bucket_name           = s3_import.value.bucket_name
      bucket_prefix         = s3_import.value.bucket_prefix
      ingestion_role        = s3_import.value.ingestion_role
      source_engine         = s3_import.value.source_engine
      source_engine_version = s3_import.value.source_engine_version
    }
  }

  tags = merge(
    var.tags,
    { Name = var.cluster_identifier }
  )

  lifecycle {
    ignore_changes = [availability_zones]

    precondition {
      condition     = var.manage_master_user_password || var.master_password != null || var.snapshot_identifier != null || var.replication_source_identifier != null || var.global_cluster_identifier != null
      error_message = "Set manage_master_user_password = true or provide master_password (unless restoring from a snapshot or creating a replica)."
    }

    precondition {
      condition     = var.kms_key_id == null || var.storage_encrypted
      error_message = "kms_key_id requires storage_encrypted = true."
    }
  }

  depends_on = [aws_cloudwatch_log_group.this]
}

# Cluster Instances
resource "aws_rds_cluster_instance" "this" {
  for_each = var.create_cluster ? var.cluster_instances : {}

  identifier         = coalesce(each.value.identifier, "${var.cluster_identifier}-${each.key}")
  cluster_identifier = aws_rds_cluster.this[0].id
  engine             = aws_rds_cluster.this[0].engine
  engine_version     = aws_rds_cluster.this[0].engine_version
  instance_class     = coalesce(each.value.instance_class, var.instance_class)

  db_subnet_group_name    = local.db_subnet_group_name
  db_parameter_group_name = try(coalesce(each.value.db_parameter_group_name, local.db_parameter_group_name), null)
  availability_zone       = each.value.availability_zone
  publicly_accessible     = each.value.publicly_accessible
  promotion_tier          = each.value.promotion_tier
  ca_cert_identifier      = each.value.ca_cert_identifier

  apply_immediately            = coalesce(each.value.apply_immediately, var.apply_immediately)
  auto_minor_version_upgrade   = coalesce(each.value.auto_minor_version_upgrade, var.auto_minor_version_upgrade)
  copy_tags_to_snapshot        = coalesce(each.value.copy_tags_to_snapshot, var.copy_tags_to_snapshot)
  preferred_maintenance_window = each.value.preferred_maintenance_window
  preferred_backup_window      = each.value.preferred_backup_window

  monitoring_interval = coalesce(each.value.monitoring_interval, var.monitoring_interval)
  monitoring_role_arn = coalesce(each.value.monitoring_interval, var.monitoring_interval) > 0 ? local.monitoring_role_arn : null

  performance_insights_enabled          = each.value.performance_insights_enabled
  performance_insights_kms_key_id       = each.value.performance_insights_kms_key_id
  performance_insights_retention_period = each.value.performance_insights_retention_period

  custom_iam_instance_profile = each.value.custom_iam_instance_profile
  force_destroy               = each.value.force_destroy

  tags = merge(
    var.tags,
    each.value.tags,
    { Name = coalesce(each.value.identifier, "${var.cluster_identifier}-${each.key}") }
  )

  depends_on = [aws_iam_role_policy_attachment.monitoring]
}

# Custom Cluster Endpoints (toggle: cluster_endpoints)
resource "aws_rds_cluster_endpoint" "this" {
  for_each = var.create_cluster ? var.cluster_endpoints : {}

  cluster_identifier          = aws_rds_cluster.this[0].id
  cluster_endpoint_identifier = coalesce(each.value.identifier, "${var.cluster_identifier}-${each.key}")
  custom_endpoint_type        = each.value.type
  static_members              = [for key in each.value.static_member_keys : aws_rds_cluster_instance.this[key].id]
  excluded_members            = [for key in each.value.excluded_member_keys : aws_rds_cluster_instance.this[key].id]

  tags = merge(
    var.tags,
    { Name = coalesce(each.value.identifier, "${var.cluster_identifier}-${each.key}") }
  )
}
