# --- Event bus -----------------------------------------------------------------

variable "create_event_bus" {
  description = "Create a custom event bus named event_bus_name. False attaches the rules to event_bus_name (null = default bus)"
  type        = bool
  default     = false
}

variable "event_bus_name" {
  description = "Event bus name or ARN. Null uses the default bus"
  type        = string
  default     = null
}

variable "event_bus_description" {
  description = "Description of the custom event bus"
  type        = string
  default     = null
}

variable "event_bus_event_source_name" {
  description = "Partner event source matched with the custom event bus"
  type        = string
  default     = null
}

variable "event_bus_kms_key_identifier" {
  description = "KMS key for events on the custom event bus"
  type        = string
  default     = null
}

variable "event_bus_dead_letter_arn" {
  description = "SQS queue ARN used as the custom event bus dead-letter queue"
  type        = string
  default     = null
}

variable "event_bus_log_config" {
  description = "Custom event bus logging. include_detail is NONE or FULL, level is OFF, ERROR, INFO or TRACE"
  type = object({
    include_detail = optional(string)
    level          = optional(string)
  })
  default = null
}

variable "tags" {
  description = "Tags applied to the event bus and every rule"
  type        = map(string)
  default     = {}
}

# --- Rules and targets ---------------------------------------------------------

variable "rules" {
  description = "Rules keyed by a short name. event_pattern is a JSON string; state is ENABLED, DISABLED or ENABLED_WITH_ALL_CLOUDTRAIL_MANAGEMENT_EVENTS. targets are keyed by a short name used as target_id"
  type = map(object({
    name                = optional(string)
    name_prefix         = optional(string)
    description         = optional(string)
    event_pattern       = optional(string)
    schedule_expression = optional(string)
    state               = optional(string, "ENABLED")
    role_arn            = optional(string)
    force_destroy       = optional(bool)
    tags                = optional(map(string), {})

    targets = optional(map(object({
      arn           = string
      target_id     = optional(string)
      role_arn      = optional(string)
      input         = optional(string)
      input_path    = optional(string)
      force_destroy = optional(bool)

      input_transformer = optional(object({
        input_paths    = optional(map(string))
        input_template = string
      }))

      retry_policy = optional(object({
        maximum_event_age_in_seconds = optional(number)
        maximum_retry_attempts       = optional(number)
      }))

      dead_letter_arn            = optional(string)
      sqs_message_group_id       = optional(string)
      kinesis_partition_key_path = optional(string)
      appsync_graphql_operation  = optional(string)

      http_target = optional(object({
        header_parameters       = optional(map(string))
        path_parameter_values   = optional(list(string))
        query_string_parameters = optional(map(string))
      }))

      run_command_targets = optional(list(object({
        key    = string
        values = list(string)
      })), [])

      ecs_target = optional(object({
        task_definition_arn     = string
        task_count              = optional(number)
        launch_type             = optional(string)
        platform_version        = optional(string)
        group                   = optional(string)
        enable_ecs_managed_tags = optional(bool)
        enable_execute_command  = optional(bool)
        propagate_tags          = optional(string)
        tags                    = optional(map(string))
        network_configuration = optional(object({
          subnets          = list(string)
          security_groups  = optional(list(string))
          assign_public_ip = optional(bool)
        }))
        capacity_provider_strategy = optional(list(object({
          capacity_provider = string
          weight            = number
          base              = optional(number)
        })), [])
        ordered_placement_strategy = optional(list(object({
          type  = string
          field = optional(string)
        })), [])
        placement_constraint = optional(list(object({
          type       = string
          expression = optional(string)
        })), [])
      }))

      batch_target = optional(object({
        job_definition = string
        job_name       = string
        array_size     = optional(number)
        job_attempts   = optional(number)
      }))

      redshift_target = optional(object({
        database            = string
        db_user             = optional(string)
        secrets_manager_arn = optional(string)
        sql                 = optional(string)
        statement_name      = optional(string)
        with_event          = optional(bool)
      }))

      sagemaker_pipeline_parameters = optional(map(string), {})
    })), {})
  }))
  default = {}
}
