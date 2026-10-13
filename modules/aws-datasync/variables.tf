variable "name_prefix" {
  description = "Prefix used for generated location, task, role and log group names"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "agents" {
  description = "DataSync agents to register, keyed by a short name. Only needed for on premises or other cloud sources"
  type = map(object({
    name                  = optional(string)
    activation_key        = optional(string)
    ip_address            = optional(string)
    private_link_endpoint = optional(string)
    security_group_arns   = optional(list(string))
    subnet_arns           = optional(list(string))
    vpc_endpoint_id       = optional(string)
    tags                  = optional(map(string), {})
  }))
  default = {}
}

variable "s3_locations" {
  description = "S3 locations, keyed by a short name. Tasks refer to these as s3.<key>"
  type = map(object({
    s3_bucket_arn    = string
    subdirectory     = optional(string, "/")
    s3_storage_class = optional(string, "STANDARD")

    # Agents are only required for S3 compatible storage outside AWS
    agent_keys = optional(list(string), [])
    agent_arns = optional(list(string))

    # read grants the DataSync role source permissions only, write grants the
    # full set needed on a destination bucket.
    access_mode = optional(string, "write")

    create_iam_role = optional(bool, true)
    iam_role_name   = optional(string)
    iam_role_arn    = optional(string)

    # CMKs the role must be able to use, for example when the bucket is SSE-KMS
    kms_key_arns = optional(list(string), [])

    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for key, location in var.s3_locations :
      contains(["read", "write"], location.access_mode)
    ])
    error_message = "access_mode must be read or write."
  }

  validation {
    condition = alltrue([
      for key, location in var.s3_locations :
      location.create_iam_role || location.iam_role_arn != null
    ])
    error_message = "An S3 location must either create its IAM role or be given iam_role_arn."
  }
}

variable "nfs_locations" {
  description = "NFS locations, keyed by a short name. Tasks refer to these as nfs.<key>"
  type = map(object({
    server_hostname = string
    subdirectory    = string
    nfs_version     = optional(string)
    agent_keys      = optional(list(string), [])
    agent_arns      = optional(list(string))
    tags            = optional(map(string), {})
  }))
  default = {}
}

variable "smb_locations" {
  description = "SMB locations, keyed by a short name. Tasks refer to these as smb.<key>"
  type = map(object({
    server_hostname = string
    subdirectory    = string
    user            = string
    password        = string
    domain          = optional(string)
    smb_version     = optional(string)
    agent_keys      = optional(list(string), [])
    agent_arns      = optional(list(string))
    tags            = optional(map(string), {})
  }))
  default   = {}
  sensitive = true
}

variable "efs_locations" {
  description = "EFS locations, keyed by a short name. Tasks refer to these as efs.<key>"
  type = map(object({
    efs_file_system_arn         = string
    subdirectory                = optional(string, "/")
    access_point_arn            = optional(string)
    file_system_access_role_arn = optional(string)
    in_transit_encryption       = optional(string)
    security_group_arns         = list(string)
    subnet_arn                  = string
    tags                        = optional(map(string), {})
  }))
  default = {}
}

variable "tasks" {
  description = "Transfer tasks, keyed by a short name. Locations are referenced as <type>.<key> or by raw ARN"
  type = map(object({
    name = optional(string)

    source_location_key      = optional(string)
    source_location_arn      = optional(string)
    destination_location_key = optional(string)
    destination_location_arn = optional(string)

    # Cron or rate expression, for example cron(0 18 * * ? *). Omit for manual runs
    schedule_expression = optional(string)

    # BASIC or ENHANCED. Enhanced is S3-to-S3 only, has no per-task object ceiling
    # (Basic caps at 25 million objects between AWS storage services) and is what
    # AWS requires for transferring without an agent. Leave null for the AWS
    # default, which is BASIC.
    task_mode = optional(string)

    create_cloudwatch_log_group      = optional(bool, true)
    cloudwatch_log_group_name        = optional(string)
    cloudwatch_log_group_arn         = optional(string)
    cloudwatch_log_retention_in_days = optional(number, 30)
    cloudwatch_log_group_kms_key_id  = optional(string)

    options = optional(object({
      atime                          = optional(string, "BEST_EFFORT")
      mtime                          = optional(string, "PRESERVE")
      uid                            = optional(string, "INT_VALUE")
      gid                            = optional(string, "INT_VALUE")
      bytes_per_second               = optional(number, -1)
      log_level                      = optional(string, "BASIC")
      overwrite_mode                 = optional(string, "ALWAYS")
      posix_permissions              = optional(string, "PRESERVE")
      preserve_deleted_files         = optional(string, "PRESERVE")
      preserve_devices               = optional(string, "NONE")
      security_descriptor_copy_flags = optional(string)
      task_queueing                  = optional(string, "ENABLED")
      transfer_mode                  = optional(string, "CHANGED")
      verify_mode                    = optional(string, "ONLY_FILES_TRANSFERRED")
      object_tags                    = optional(string, "PRESERVE")
    }))

    includes = optional(object({
      filter_type = optional(string, "SIMPLE_PATTERN")
      value       = string
    }))

    excludes = optional(object({
      filter_type = optional(string, "SIMPLE_PATTERN")
      value       = string
    }))

    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for key, task in var.tasks :
      (task.source_location_key != null || task.source_location_arn != null) &&
      (task.destination_location_key != null || task.destination_location_arn != null)
    ])
    error_message = "Each task needs a source and a destination, given either as a location key or as a raw ARN."
  }

  validation {
    condition = alltrue([
      for key, task in var.tasks :
      task.task_mode == null || contains(["BASIC", "ENHANCED"], task.task_mode)
    ])
    error_message = "task_mode must be BASIC or ENHANCED."
  }

  # Enhanced mode accepts transfer options; only these two settings are rejected.
  # Leaving options unset is NOT equivalent to leaving them at sensible values --
  # the AWS default for log_level is OFF, which silently disables CloudWatch logs.
  validation {
    condition = alltrue([
      for key, task in var.tasks :
      task.task_mode != "ENHANCED" || task.options == null || task.options.mtime != "NONE"
    ])
    error_message = "Enhanced mode tasks do not support mtime = NONE."
  }

  validation {
    condition = alltrue([
      for key, task in var.tasks :
      task.task_mode != "ENHANCED" || task.options == null || task.options.verify_mode != "POINT_IN_TIME_CONSISTENT"
    ])
    error_message = "Enhanced mode tasks do not support verify_mode = POINT_IN_TIME_CONSISTENT."
  }
}
