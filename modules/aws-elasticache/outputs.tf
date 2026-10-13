# --- Subnet and parameter groups ----------------------------------------------

output "subnet_group_name" {
  description = "Name of the cache subnet group in use, whether created here or pre-existing"
  value       = local.effective_subnet_group_name
}

output "parameter_group_name" {
  description = "Name of the parameter group in use, or null when the engine default applies"
  value       = local.effective_parameter_group_name
}

# --- Redis / Valkey -------------------------------------------------------------

output "replication_group_id" {
  description = "ID of the replication group (null for Memcached)"
  value       = one(aws_elasticache_replication_group.this[*].id)
}

output "replication_group_arn" {
  description = "ARN of the replication group (null for Memcached)"
  value       = one(aws_elasticache_replication_group.this[*].arn)
}

output "primary_endpoint_address" {
  description = "Primary endpoint for writes. Redis/Valkey with cluster mode disabled"
  value       = one(aws_elasticache_replication_group.this[*].primary_endpoint_address)
}

output "reader_endpoint_address" {
  description = "Reader endpoint for replica reads. Redis/Valkey with cluster mode disabled"
  value       = one(aws_elasticache_replication_group.this[*].reader_endpoint_address)
}

output "configuration_endpoint_address" {
  description = "Configuration endpoint. Redis/Valkey with cluster mode enabled"
  value       = one(aws_elasticache_replication_group.this[*].configuration_endpoint_address)
}

output "member_clusters" {
  description = "Identifiers of every node in the replication group"
  value       = one(aws_elasticache_replication_group.this[*].member_clusters)
}

output "cluster_enabled" {
  description = "Whether the replication group has cluster mode enabled"
  value       = one(aws_elasticache_replication_group.this[*].cluster_enabled)
}

# --- Memcached ------------------------------------------------------------------

output "cluster_id" {
  description = "ID of the Memcached cluster (null for Redis/Valkey)"
  value       = one(aws_elasticache_cluster.this[*].id)
}

output "cluster_arn" {
  description = "ARN of the Memcached cluster (null for Redis/Valkey)"
  value       = one(aws_elasticache_cluster.this[*].arn)
}

output "cluster_address" {
  description = "DNS name of the Memcached cluster without the port"
  value       = one(aws_elasticache_cluster.this[*].cluster_address)
}

output "configuration_endpoint" {
  description = "Memcached configuration endpoint used for node auto discovery"
  value       = one(aws_elasticache_cluster.this[*].configuration_endpoint)
}

output "cache_nodes" {
  description = "Memcached node objects, each with id, address, port and availability_zone"
  value       = one(aws_elasticache_cluster.this[*].cache_nodes)
}

# --- Engine agnostic ------------------------------------------------------------

output "endpoint" {
  description = "Endpoint clients should connect to, resolved for the selected engine and topology"
  value = local.is_memcached ? one(aws_elasticache_cluster.this[*].configuration_endpoint) : (
    var.cluster_mode_enabled
    ? one(aws_elasticache_replication_group.this[*].configuration_endpoint_address)
    : one(aws_elasticache_replication_group.this[*].primary_endpoint_address)
  )
}

output "engine_version_actual" {
  description = "Engine version actually running after AWS applies its latest patch level"
  value       = local.is_memcached ? one(aws_elasticache_cluster.this[*].engine_version_actual) : one(aws_elasticache_replication_group.this[*].engine_version_actual)
}
