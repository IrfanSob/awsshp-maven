# --- Cluster -------------------------------------------------------------------

output "cluster_id" {
  description = "Cluster identifier"
  value       = one(aws_rds_cluster.this[*].id)
}

output "cluster_arn" {
  description = "Cluster ARN"
  value       = one(aws_rds_cluster.this[*].arn)
}

output "cluster_resource_id" {
  description = "Cluster resource ID, used in IAM database authentication policies"
  value       = one(aws_rds_cluster.this[*].cluster_resource_id)
}

output "cluster_endpoint" {
  description = "Writer endpoint"
  value       = one(aws_rds_cluster.this[*].endpoint)
}

output "cluster_reader_endpoint" {
  description = "Reader endpoint, load-balanced across reader instances"
  value       = one(aws_rds_cluster.this[*].reader_endpoint)
}

output "cluster_port" {
  description = "Port the cluster listens on"
  value       = one(aws_rds_cluster.this[*].port)
}

output "cluster_hosted_zone_id" {
  description = "Route 53 hosted zone ID of the cluster endpoints"
  value       = one(aws_rds_cluster.this[*].hosted_zone_id)
}

output "cluster_database_name" {
  description = "Database created with the cluster"
  value       = one(aws_rds_cluster.this[*].database_name)
}

output "cluster_master_username" {
  description = "Master user name"
  value       = one(aws_rds_cluster.this[*].master_username)
}

output "cluster_master_user_secret_arn" {
  description = "ARN of the RDS-managed master user secret in Secrets Manager"
  value       = try(aws_rds_cluster.this[0].master_user_secret[0].secret_arn, null)
}

output "cluster_engine_version_actual" {
  description = "Running engine version"
  value       = one(aws_rds_cluster.this[*].engine_version_actual)
}

# --- Instances and endpoints ---------------------------------------------------

output "instance_ids" {
  description = "Map of instance keys to instance identifiers"
  value       = { for k, v in aws_rds_cluster_instance.this : k => v.id }
}

output "instance_arns" {
  description = "Map of instance keys to instance ARNs"
  value       = { for k, v in aws_rds_cluster_instance.this : k => v.arn }
}

output "instance_endpoints" {
  description = "Map of instance keys to instance endpoints"
  value       = { for k, v in aws_rds_cluster_instance.this : k => v.endpoint }
}

output "custom_endpoints" {
  description = "Map of custom endpoint keys to their DNS names"
  value       = { for k, v in aws_rds_cluster_endpoint.this : k => v.endpoint }
}

# --- Supporting resources ------------------------------------------------------

output "db_subnet_group_name" {
  description = "DB subnet group in use"
  value       = local.db_subnet_group_name
}

output "cluster_parameter_group_name" {
  description = "Cluster parameter group in use, or null for the engine default"
  value       = local.cluster_parameter_group_name
}

output "db_parameter_group_name" {
  description = "DB parameter group in use, or null for the engine default"
  value       = local.db_parameter_group_name
}

output "monitoring_role_arn" {
  description = "Enhanced Monitoring role ARN in use"
  value       = local.monitoring_role_arn
}

output "cloudwatch_log_group_names" {
  description = "Map of exported log types to the log groups created here"
  value       = { for k, v in aws_cloudwatch_log_group.this : k => v.name }
}
