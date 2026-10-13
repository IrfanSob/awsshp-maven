# --- General -------------------------------------------------------------------

variable "create_cluster" {
  description = "Whether to create the cluster and every resource in this module"
  type        = bool
  default     = true
}

variable "cluster_identifier" {
  description = "Cluster identifier, also used as the base for generated resource names"
  type        = string
}

variable "engine" {
  description = "Database engine. aurora-postgresql and aurora-mysql create an Aurora cluster, postgres and mysql create a Multi-AZ DB cluster"
  type        = string
  default     = "aurora-postgresql"

  validation {
    condition     = contains(["aurora-postgresql", "aurora-mysql", "postgres", "mysql"], var.engine)
    error_message = "engine must be one of: aurora-postgresql, aurora-mysql, postgres, mysql."
  }
}

variable "engine_version" {
  description = "Engine version, e.g. 16.6. Null uses the AWS default"
  type        = string
  default     = null
}

variable "engine_mode" {
  description = "Engine mode. Use provisioned for Aurora Serverless v2 and provisioned instances"
  type        = string
  default     = "provisioned"
}

variable "engine_lifecycle_support" {
  description = "open-source-rds-extended-support or open-source-rds-extended-support-disabled. Null keeps the AWS default"
  type        = string
  default     = null
}

variable "cluster_scalability_type" {
  description = "standard or limitless. Null keeps the AWS default (standard)"
  type        = string
  default     = null
}

variable "database_name" {
  description = "Name of the database created with the cluster. Only one database can be created this way"
  type        = string
  default     = null
}

variable "port" {
  description = "Port the cluster listens on. Null uses the engine default"
  type        = number
  default     = null
}

variable "tags" {
  description = "Tags applied to every resource in this module"
  type        = map(string)
  default     = {}
}

# --- Credentials ---------------------------------------------------------------

variable "master_username" {
  description = "Master user name. Required unless restoring from a snapshot or creating a replica"
  type        = string
  default     = null
}

variable "manage_master_user_password" {
  description = "Let RDS generate the master password and store it in Secrets Manager"
  type        = bool
  default     = true
}

variable "master_user_secret_kms_key_id" {
  description = "KMS key for the RDS-managed master user secret. Null uses aws/secretsmanager"
  type        = string
  default     = null
}

variable "master_password" {
  description = "Master password when manage_master_user_password is false"
  type        = string
  default     = null
  sensitive   = true
}

variable "iam_database_authentication_enabled" {
  description = "Enable IAM database authentication"
  type        = bool
  default     = false
}

variable "iam_roles" {
  description = "IAM role ARNs associated with the cluster, e.g. for S3 import/export"
  type        = list(string)
  default     = []
}

# --- Network -------------------------------------------------------------------

variable "vpc_security_group_ids" {
  description = "Security group IDs attached to the cluster"
  type        = list(string)
  default     = []
}

variable "create_db_subnet_group" {
  description = "Create a DB subnet group. Set false to use existing_db_subnet_group_name"
  type        = bool
  default     = true
}

variable "db_subnet_group_name" {
  description = "Name of the DB subnet group to create. Defaults to <cluster_identifier>-subnet-group"
  type        = string
  default     = null
}

variable "db_subnet_group_description" {
  description = "Description of the DB subnet group"
  type        = string
  default     = "Managed by Terraform"
}

variable "subnet_ids" {
  description = "Subnet IDs for the DB subnet group"
  type        = list(string)
  default     = []
}

variable "existing_db_subnet_group_name" {
  description = "Existing DB subnet group used when create_db_subnet_group is false"
  type        = string
  default     = null
}

variable "availability_zones" {
  description = "Availability Zones for cluster storage. Null lets RDS choose; changes are ignored after creation"
  type        = list(string)
  default     = null
}

variable "network_type" {
  description = "IPV4 or DUAL. Null keeps the AWS default"
  type        = string
  default     = null
}

variable "ca_certificate_identifier" {
  description = "CA certificate identifier for the cluster server certificate, e.g. rds-ca-rsa2048-g1"
  type        = string
  default     = null
}

# --- Storage and encryption ----------------------------------------------------

variable "storage_encrypted" {
  description = "Encrypt cluster storage"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ARN for storage encryption. Null uses aws/rds"
  type        = string
  default     = null
}

variable "storage_type" {
  description = "Aurora: aurora or aurora-iopt1. Multi-AZ DB cluster: io1, io2 or gp3. Null keeps the AWS default"
  type        = string
  default     = null
}

variable "allocated_storage" {
  description = "Storage in GiB per instance. Multi-AZ DB cluster only"
  type        = number
  default     = null
}

variable "iops" {
  description = "Provisioned IOPS per instance. Multi-AZ DB cluster only"
  type        = number
  default     = null
}

variable "db_cluster_instance_class" {
  description = "Instance class of each instance. Multi-AZ DB cluster only"
  type        = string
  default     = null
}

# --- Capacity ------------------------------------------------------------------

variable "serverlessv2_scaling_configuration" {
  description = "Aurora Serverless v2 capacity in ACU. seconds_until_auto_pause is only valid when min_capacity is 0"
  type = object({
    min_capacity             = number
    max_capacity             = number
    seconds_until_auto_pause = optional(number)
  })
  default = null
}

variable "scaling_configuration" {
  description = "Aurora Serverless v1 scaling, only valid when engine_mode is serverless"
  type = object({
    auto_pause               = optional(bool)
    min_capacity             = optional(number)
    max_capacity             = optional(number)
    seconds_before_timeout   = optional(number)
    seconds_until_auto_pause = optional(number)
    timeout_action           = optional(string)
  })
  default = null
}

variable "instance_class" {
  description = "Default instance class for cluster_instances. db.serverless for Aurora Serverless v2"
  type        = string
  default     = "db.serverless"
}

variable "cluster_instances" {
  description = "Cluster instances keyed by a short name (e.g. writer, reader1). Empty creates no instance. Null fields fall back to the module-level value"
  type = map(object({
    identifier                            = optional(string)
    instance_class                        = optional(string)
    availability_zone                     = optional(string)
    promotion_tier                        = optional(number)
    publicly_accessible                   = optional(bool, false)
    db_parameter_group_name               = optional(string)
    ca_cert_identifier                    = optional(string)
    apply_immediately                     = optional(bool)
    auto_minor_version_upgrade            = optional(bool)
    copy_tags_to_snapshot                 = optional(bool)
    preferred_maintenance_window          = optional(string)
    preferred_backup_window               = optional(string)
    monitoring_interval                   = optional(number)
    performance_insights_enabled          = optional(bool)
    performance_insights_kms_key_id       = optional(string)
    performance_insights_retention_period = optional(number)
    custom_iam_instance_profile           = optional(string)
    force_destroy                         = optional(bool)
    tags                                  = optional(map(string), {})
  }))
  default = {}
}

variable "cluster_endpoints" {
  description = "Custom cluster endpoints keyed by a short name. type is READER or ANY; members refer to cluster_instances keys"
  type = map(object({
    identifier           = optional(string)
    type                 = string
    static_member_keys   = optional(list(string), [])
    excluded_member_keys = optional(list(string), [])
  }))
  default = {}
}

# --- Parameter groups ----------------------------------------------------------

variable "create_cluster_parameter_group" {
  description = "Create a cluster parameter group. Set false to use existing_cluster_parameter_group_name or the engine default"
  type        = bool
  default     = false
}

variable "cluster_parameter_group_name" {
  description = "Name of the cluster parameter group to create. Defaults to <cluster_identifier>-cluster-pg"
  type        = string
  default     = null
}

variable "cluster_parameter_group_family" {
  description = "Cluster parameter group family, e.g. aurora-postgresql16"
  type        = string
  default     = null
}

variable "cluster_parameter_group_description" {
  description = "Description of the cluster parameter group"
  type        = string
  default     = "Managed by Terraform"
}

variable "cluster_parameters" {
  description = "Cluster parameters. apply_method is immediate or pending-reboot"
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "immediate")
  }))
  default = []
}

variable "existing_cluster_parameter_group_name" {
  description = "Existing cluster parameter group used when create_cluster_parameter_group is false"
  type        = string
  default     = null
}

variable "create_db_parameter_group" {
  description = "Create a DB (instance) parameter group. Set false to use existing_db_parameter_group_name or the engine default"
  type        = bool
  default     = false
}

variable "db_parameter_group_name" {
  description = "Name of the DB parameter group to create. Defaults to <cluster_identifier>-instance-pg"
  type        = string
  default     = null
}

variable "db_parameter_group_family" {
  description = "DB parameter group family, e.g. aurora-postgresql16"
  type        = string
  default     = null
}

variable "db_parameter_group_description" {
  description = "Description of the DB parameter group"
  type        = string
  default     = "Managed by Terraform"
}

variable "db_parameters" {
  description = "DB (instance) parameters. apply_method is immediate or pending-reboot"
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "immediate")
  }))
  default = []
}

variable "db_parameter_group_skip_destroy" {
  description = "Keep the DB parameter group on destroy and only remove it from state"
  type        = bool
  default     = false
}

variable "existing_db_parameter_group_name" {
  description = "Existing DB parameter group used when create_db_parameter_group is false"
  type        = string
  default     = null
}

variable "db_instance_parameter_group_name" {
  description = "Instance parameter group applied to all instances during a major version upgrade. Only used when allow_major_version_upgrade is true"
  type        = string
  default     = null
}

# --- Backup, restore and maintenance -------------------------------------------

variable "backup_retention_period" {
  description = "Days to retain automated backups (1-35)"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Daily backup window in UTC, e.g. 17:00-18:00"
  type        = string
  default     = null
}

variable "preferred_maintenance_window" {
  description = "Weekly maintenance window in UTC, e.g. sun:18:00-sun:19:00"
  type        = string
  default     = null
}

variable "copy_tags_to_snapshot" {
  description = "Copy cluster tags to snapshots"
  type        = bool
  default     = true
}

variable "backtrack_window" {
  description = "Backtrack window in seconds (aurora-mysql only). Null or 0 disables it"
  type        = number
  default     = null
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on delete"
  type        = bool
  default     = false
}

variable "final_snapshot_identifier" {
  description = "Final snapshot name. Defaults to <cluster_identifier>-final-snapshot"
  type        = string
  default     = null
}

variable "delete_automated_backups" {
  description = "Remove automated backups immediately after the cluster is deleted"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Protect the cluster from deletion"
  type        = bool
  default     = true
}

variable "snapshot_identifier" {
  description = "Snapshot name or ARN to create the cluster from"
  type        = string
  default     = null
}

variable "restore_to_point_in_time" {
  description = "Point-in-time restore settings"
  type = object({
    restore_to_time            = optional(string)
    restore_type               = optional(string)
    source_cluster_identifier  = optional(string)
    source_cluster_resource_id = optional(string)
    use_latest_restorable_time = optional(bool)
  })
  default = null
}

variable "s3_import" {
  description = "Restore from a backup stored in S3 (aurora-mysql only)"
  type = object({
    bucket_name           = string
    bucket_prefix         = optional(string)
    ingestion_role        = string
    source_engine         = string
    source_engine_version = string
  })
  default = null
}

variable "apply_immediately" {
  description = "Apply modifications immediately instead of in the next maintenance window"
  type        = bool
  default     = false
}

variable "allow_major_version_upgrade" {
  description = "Allow major engine version upgrades"
  type        = bool
  default     = false
}

variable "auto_minor_version_upgrade" {
  description = "Apply minor engine upgrades automatically"
  type        = bool
  default     = true
}

# --- Monitoring ----------------------------------------------------------------

variable "enabled_cloudwatch_logs_exports" {
  description = "Log types exported to CloudWatch Logs, e.g. [\"postgresql\"] or [\"audit\", \"error\", \"general\", \"slowquery\"]"
  type        = list(string)
  default     = []
}

variable "create_cloudwatch_log_groups" {
  description = "Pre-create the export log groups so retention and encryption are managed here"
  type        = bool
  default     = false
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "Retention of the export log groups"
  type        = number
  default     = 30
}

variable "cloudwatch_log_group_kms_key_id" {
  description = "KMS key ARN for the export log groups"
  type        = string
  default     = null
}

variable "cloudwatch_log_group_class" {
  description = "STANDARD or INFREQUENT_ACCESS"
  type        = string
  default     = null
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights at cluster level"
  type        = bool
  default     = false
}

variable "performance_insights_kms_key_id" {
  description = "KMS key ARN for Performance Insights data. Null uses aws/rds"
  type        = string
  default     = null
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention in days: 7, a multiple of 31, or 731. Advanced Database Insights requires 465"
  type        = number
  default     = 7
}

variable "database_insights_mode" {
  description = "standard or advanced. Null keeps the AWS default"
  type        = string
  default     = null
}

variable "monitoring_interval" {
  description = "Enhanced Monitoring interval in seconds (0, 1, 5, 10, 15, 30, 60). 0 disables it"
  type        = number
  default     = 0
}

variable "create_monitoring_role" {
  description = "Create the Enhanced Monitoring IAM role"
  type        = bool
  default     = false
}

variable "monitoring_role_name" {
  description = "Name of the Enhanced Monitoring role. Defaults to <cluster_identifier>-rds-monitoring-role"
  type        = string
  default     = null
}

variable "monitoring_role_arn" {
  description = "Existing Enhanced Monitoring role ARN used when create_monitoring_role is false"
  type        = string
  default     = null
}


# --- Advanced ------------------------------------------------------------------

variable "enable_http_endpoint" {
  description = "Enable the RDS Data API. Not available in every Region (e.g. ap-southeast-3)"
  type        = bool
  default     = false
}

variable "enable_global_write_forwarding" {
  description = "Forward writes from a secondary cluster to the global cluster primary"
  type        = bool
  default     = null
}

variable "enable_local_write_forwarding" {
  description = "Forward writes from reader instances to the writer"
  type        = bool
  default     = null
}

variable "global_cluster_identifier" {
  description = "Global cluster identifier to join"
  type        = string
  default     = null
}

variable "replication_source_identifier" {
  description = "ARN of a source cluster or instance when creating a read replica cluster"
  type        = string
  default     = null
}

variable "source_region" {
  description = "Source Region of an encrypted replica cluster"
  type        = string
  default     = null
}

variable "domain" {
  description = "Directory Service domain ID for Kerberos authentication"
  type        = string
  default     = null
}

variable "domain_iam_role_name" {
  description = "IAM role used to call Directory Service. Required when domain is set"
  type        = string
  default     = null
}

variable "db_system_id" {
  description = "RDS Custom system ID"
  type        = string
  default     = null
}
