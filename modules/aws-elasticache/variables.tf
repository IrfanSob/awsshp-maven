# --- General -------------------------------------------------------------------

variable "name" {
  description = "Name used as the replication group ID (Redis/Valkey) or cluster ID (Memcached), and as the base for generated resource names"
  type        = string
}

variable "engine" {
  description = "Cache engine to deploy. redis and valkey create a replication group, memcached creates a cache cluster"
  type        = string
  default     = "valkey"

  validation {
    condition     = contains(["redis", "valkey", "memcached"], var.engine)
    error_message = "engine must be one of: redis, valkey, memcached."
  }
}

variable "engine_version" {
  description = "Engine version. Omit to use the AWS default for the selected engine"
  type        = string
  default     = null
}

variable "node_type" {
  description = "Node instance class, e.g. cache.t4g.micro"
  type        = string
}

variable "port" {
  description = "Port the cache listens on. Defaults to 6379 for Redis/Valkey and 11211 for Memcached when null"
  type        = number
  default     = null
}

variable "description" {
  description = "Description of the replication group. Redis/Valkey only, and required by AWS for those engines"
  type        = string
  default     = "Managed by Terraform"
}

variable "security_group_ids" {
  description = "VPC security group IDs to associate with the cache"
  type        = list(string)
  default     = []
}

# --- Subnet group --------------------------------------------------------------

variable "create_subnet_group" {
  description = "Whether to create a cache subnet group. Set to false to use one that already exists"
  type        = bool
  default     = true
}

variable "subnet_group_name" {
  description = "Name of the subnet group to create. Defaults to <name>-subnet-group"
  type        = string
  default     = null
}

variable "subnet_group_description" {
  description = "Description of the created subnet group"
  type        = string
  default     = "Managed by Terraform"
}

variable "subnet_ids" {
  description = "Subnet IDs for the created subnet group. Required when create_subnet_group is true"
  type        = list(string)
  default     = []
}

variable "existing_subnet_group_name" {
  description = "Name of an existing cache subnet group to use when create_subnet_group is false"
  type        = string
  default     = null
}

# --- Parameter group -----------------------------------------------------------

variable "create_parameter_group" {
  description = "Whether to create a cache parameter group. When false the AWS default for the engine version is used unless existing_parameter_group_name is set"
  type        = bool
  default     = false
}

variable "parameter_group_name" {
  description = "Name of the parameter group to create. Defaults to <name>-parameter-group"
  type        = string
  default     = null
}

variable "parameter_group_family" {
  description = "Parameter group family, e.g. valkey8, redis7, memcached1.6. Required when create_parameter_group is true"
  type        = string
  default     = null
}

variable "parameter_group_description" {
  description = "Description of the created parameter group"
  type        = string
  default     = "Managed by Terraform"
}

variable "parameters" {
  description = "Parameters to set on the created parameter group"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "existing_parameter_group_name" {
  description = "Name of an existing parameter group to use when create_parameter_group is false"
  type        = string
  default     = null
}

# --- Redis / Valkey topology ---------------------------------------------------

variable "num_cache_clusters" {
  description = "Number of nodes in the replication group, primary included. Used when cluster_mode_enabled is false"
  type        = number
  default     = 1
}

variable "preferred_cache_cluster_azs" {
  description = "Availability zones for the nodes, in order. The first entry hosts the primary. Used when cluster_mode_enabled is false"
  type        = list(string)
  default     = null
}

variable "cluster_mode_enabled" {
  description = "Whether to shard the data across multiple node groups. Switches the topology to num_node_groups and replicas_per_node_group"
  type        = bool
  default     = false
}

variable "num_node_groups" {
  description = "Number of shards. Required when cluster_mode_enabled is true"
  type        = number
  default     = null
}

variable "replicas_per_node_group" {
  description = "Number of read replicas per shard. Used when cluster_mode_enabled is true"
  type        = number
  default     = null
}

variable "automatic_failover_enabled" {
  description = "Promote a replica to primary if the primary fails. Requires more than one node"
  type        = bool
  default     = false
}

variable "multi_az_enabled" {
  description = "Spread nodes across availability zones. Requires automatic_failover_enabled"
  type        = bool
  default     = false
}

variable "data_tiering_enabled" {
  description = "Enable data tiering to SSD. Only valid on r6gd node types"
  type        = bool
  default     = null
}

# --- Memcached topology --------------------------------------------------------

variable "num_cache_nodes" {
  description = "Number of nodes in the Memcached cluster"
  type        = number
  default     = 1
}

variable "az_mode" {
  description = "Whether Memcached nodes sit in one availability zone or several"
  type        = string
  default     = "single-az"

  validation {
    condition     = contains(["single-az", "cross-az"], var.az_mode)
    error_message = "az_mode must be either single-az or cross-az."
  }
}

variable "preferred_availability_zones" {
  description = "Availability zones for the Memcached nodes. Must contain exactly num_cache_nodes entries when set"
  type        = list(string)
  default     = []
}

# --- Encryption and access -----------------------------------------------------

variable "at_rest_encryption_enabled" {
  description = "Encrypt data at rest. Redis/Valkey only"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "Encrypt data in transit. Clients must connect over TLS when enabled. Memcached requires engine version 1.6.12 or later"
  type        = bool
  default     = true
}

variable "transit_encryption_mode" {
  description = "Transit encryption migration mode. Set to preferred before moving an existing cache to required"
  type        = string
  default     = null

  validation {
    condition     = contains(["preferred", "required"], coalesce(var.transit_encryption_mode, "preferred"))
    error_message = "transit_encryption_mode must be either preferred or required."
  }
}

variable "auth_token" {
  description = "Password used to access a password protected cache. Requires transit_encryption_enabled"
  type        = string
  default     = null
  sensitive   = true
}

variable "auth_token_update_strategy" {
  description = "How to apply a change to auth_token. One of SET, ROTATE or DELETE"
  type        = string
  default     = "ROTATE"

  validation {
    condition     = contains(["SET", "ROTATE", "DELETE"], var.auth_token_update_strategy)
    error_message = "auth_token_update_strategy must be one of: SET, ROTATE, DELETE."
  }
}

variable "kms_key_id" {
  description = "ARN of the KMS key used for encryption at rest. Uses the AWS managed key when null"
  type        = string
  default     = null
}

variable "user_group_ids" {
  description = "ElastiCache user group ID for RBAC access control. At most one"
  type        = list(string)
  default     = null
}

# --- Backups -------------------------------------------------------------------

variable "snapshot_retention_limit" {
  description = "Days to retain automatic snapshots. Zero disables automatic snapshots. Redis/Valkey only"
  type        = number
  default     = 0
}

variable "snapshot_window" {
  description = "Daily UTC window for automatic snapshots, e.g. 03:00-05:00. Redis/Valkey only"
  type        = string
  default     = null
}

variable "final_snapshot_identifier" {
  description = "Name of the snapshot taken when the replication group is destroyed. No final snapshot when null"
  type        = string
  default     = null
}

# --- Maintenance and monitoring ------------------------------------------------

variable "maintenance_window" {
  description = "Weekly UTC maintenance window, e.g. sun:05:00-sun:09:00"
  type        = string
  default     = null
}

variable "auto_minor_version_upgrade" {
  description = "Apply minor engine upgrades automatically. Redis/Valkey 6 and later"
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply changes immediately rather than waiting for the maintenance window"
  type        = bool
  default     = false
}

variable "notification_topic_arn" {
  description = "SNS topic ARN to receive ElastiCache notifications"
  type        = string
  default     = null
}

variable "log_delivery_configurations" {
  description = "Log delivery configurations for slow log and engine log. Redis/Valkey only, at most two entries"
  type = list(object({
    destination      = string
    destination_type = string
    log_format       = string
    log_type         = string
  }))
  default = []
}

# --- Tags ----------------------------------------------------------------------

variable "tags" {
  description = "A map of tags to apply to all resources created by this module"
  type        = map(string)
  default     = {}
}
