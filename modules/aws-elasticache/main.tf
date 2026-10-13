locals {
  is_memcached  = var.engine == "memcached"
  is_redis_like = contains(["redis", "valkey"], var.engine)

  subnet_group_name = coalesce(var.subnet_group_name, "${var.name}-subnet-group")

  parameter_group_name_resolved = coalesce(var.parameter_group_name, "${var.name}-parameter-group")

  # Resolve through the created resource so the cache waits on it, and fall
  # back to a pre-existing group when this module does not create one.
  effective_subnet_group_name = (
    var.create_subnet_group
    ? one(aws_elasticache_subnet_group.this[*].name)
    : var.existing_subnet_group_name
  )

  effective_parameter_group_name = (
    var.create_parameter_group
    ? one(aws_elasticache_parameter_group.this[*].name)
    : var.existing_parameter_group_name
  )
}

# Subnet Group
resource "aws_elasticache_subnet_group" "this" {
  count = var.create_subnet_group ? 1 : 0

  name        = local.subnet_group_name
  description = var.subnet_group_description
  subnet_ids  = var.subnet_ids

  tags = merge(
    var.tags,
    { "Name" = local.subnet_group_name }
  )

  lifecycle {
    precondition {
      condition     = length(var.subnet_ids) > 0
      error_message = "subnet_ids must not be empty when create_subnet_group is true."
    }
  }
}

# Parameter Group
resource "aws_elasticache_parameter_group" "this" {
  count = var.create_parameter_group ? 1 : 0

  name        = local.parameter_group_name_resolved
  family      = var.parameter_group_family
  description = var.parameter_group_description

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = merge(
    var.tags,
    { "Name" = local.parameter_group_name_resolved }
  )

  lifecycle {
    precondition {
      condition     = var.parameter_group_family != null
      error_message = "parameter_group_family is required when create_parameter_group is true (e.g. valkey8, redis7, memcached1.6)."
    }
  }
}

# Redis OSS / Valkey - replication group
resource "aws_elasticache_replication_group" "this" {
  count = local.is_redis_like ? 1 : 0

  replication_group_id = var.name
  description          = var.description

  engine         = var.engine
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = var.port

  subnet_group_name    = local.effective_subnet_group_name
  security_group_ids   = var.security_group_ids
  parameter_group_name = local.effective_parameter_group_name

  # num_cache_clusters conflicts with the sharded cluster-mode arguments,
  # so only one of the two shapes is ever sent.
  num_cache_clusters          = var.cluster_mode_enabled ? null : var.num_cache_clusters
  preferred_cache_cluster_azs = var.cluster_mode_enabled ? null : var.preferred_cache_cluster_azs
  num_node_groups             = var.cluster_mode_enabled ? var.num_node_groups : null
  replicas_per_node_group     = var.cluster_mode_enabled ? var.replicas_per_node_group : null

  automatic_failover_enabled = var.automatic_failover_enabled
  multi_az_enabled           = var.multi_az_enabled

  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  transit_encryption_mode    = var.transit_encryption_mode
  auth_token                 = var.auth_token
  auth_token_update_strategy = var.auth_token != null ? var.auth_token_update_strategy : null
  kms_key_id                 = var.kms_key_id
  user_group_ids             = var.user_group_ids

  snapshot_retention_limit  = var.snapshot_retention_limit
  snapshot_window           = var.snapshot_window
  final_snapshot_identifier = var.final_snapshot_identifier

  maintenance_window         = var.maintenance_window
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately
  notification_topic_arn     = var.notification_topic_arn
  data_tiering_enabled       = var.data_tiering_enabled

  dynamic "log_delivery_configuration" {
    for_each = var.log_delivery_configurations
    content {
      destination      = log_delivery_configuration.value.destination
      destination_type = log_delivery_configuration.value.destination_type
      log_format       = log_delivery_configuration.value.log_format
      log_type         = log_delivery_configuration.value.log_type
    }
  }

  tags = merge(
    var.tags,
    { "Name" = var.name }
  )

  lifecycle {
    precondition {
      condition     = !var.multi_az_enabled || var.automatic_failover_enabled
      error_message = "multi_az_enabled requires automatic_failover_enabled to be true."
    }

    precondition {
      condition = (
        !var.automatic_failover_enabled ||
        var.cluster_mode_enabled ||
        var.num_cache_clusters > 1
      )
      error_message = "automatic_failover_enabled requires num_cache_clusters greater than 1."
    }

    precondition {
      condition     = !var.cluster_mode_enabled || var.num_node_groups != null
      error_message = "num_node_groups is required when cluster_mode_enabled is true."
    }

    precondition {
      condition = (
        var.cluster_mode_enabled ||
        var.preferred_cache_cluster_azs == null ||
        length(var.preferred_cache_cluster_azs) == var.num_cache_clusters
      )
      error_message = "preferred_cache_cluster_azs must contain exactly num_cache_clusters entries. The first entry hosts the primary node."
    }

    precondition {
      condition     = var.auth_token == null || var.transit_encryption_enabled
      error_message = "auth_token requires transit_encryption_enabled to be true."
    }
  }
}

# Memcached - cache cluster
resource "aws_elasticache_cluster" "this" {
  count = local.is_memcached ? 1 : 0

  cluster_id      = var.name
  engine          = var.engine
  engine_version  = var.engine_version
  node_type       = var.node_type
  num_cache_nodes = var.num_cache_nodes
  port            = var.port

  az_mode                      = var.az_mode
  preferred_availability_zones = var.preferred_availability_zones

  subnet_group_name    = local.effective_subnet_group_name
  security_group_ids   = var.security_group_ids
  parameter_group_name = local.effective_parameter_group_name

  transit_encryption_enabled = var.transit_encryption_enabled
  maintenance_window         = var.maintenance_window
  notification_topic_arn     = var.notification_topic_arn
  apply_immediately          = var.apply_immediately

  tags = merge(
    var.tags,
    { "Name" = var.name }
  )

  lifecycle {
    precondition {
      condition = (
        var.az_mode != "cross-az" ||
        var.num_cache_nodes > 1
      )
      error_message = "az_mode cross-az requires num_cache_nodes greater than 1."
    }

    precondition {
      condition = (
        length(var.preferred_availability_zones) == 0 ||
        length(var.preferred_availability_zones) == var.num_cache_nodes
      )
      error_message = "preferred_availability_zones must contain exactly num_cache_nodes entries when set."
    }
  }
}
