# --- General -------------------------------------------------------------------

variable "create_application" {
  description = "Create the CodeDeploy application. Set false to add deployment groups to an existing application named application_name"
  type        = bool
  default     = true
}

variable "application_name" {
  description = "CodeDeploy application name"
  type        = string
}

variable "compute_platform" {
  description = "ECS, Server or Lambda"
  type        = string
  default     = "ECS"

  validation {
    condition     = contains(["ECS", "Server", "Lambda"], var.compute_platform)
    error_message = "compute_platform must be ECS, Server or Lambda."
  }
}

variable "tags" {
  description = "Tags applied to every taggable resource in this module"
  type        = map(string)
  default     = {}
}

# --- Service role --------------------------------------------------------------

variable "create_service_role" {
  description = "Create the CodeDeploy service role"
  type        = bool
  default     = true
}

variable "service_role_arn" {
  description = "Existing service role ARN used when create_service_role is false"
  type        = string
  default     = null
}

variable "service_role_name" {
  description = "Service role name. Defaults to <application_name>-codedeploy-role"
  type        = string
  default     = null
}

variable "service_role_path" {
  description = "IAM path of the service role"
  type        = string
  default     = "/"
}

variable "service_role_permissions_boundary" {
  description = "Permissions boundary ARN for the service role"
  type        = string
  default     = null
}

variable "attach_default_service_role_policy" {
  description = "Attach the AWS managed CodeDeploy policy for the compute platform (AWSCodeDeployRoleForECS, AWSCodeDeployRole or AWSCodeDeployRoleForLambda)"
  type        = bool
  default     = true
}

variable "service_role_managed_policy_arns" {
  description = "Extra managed policy ARNs attached to the service role"
  type        = list(string)
  default     = []
}

variable "service_role_inline_policies" {
  description = "Extra inline policies keyed by policy name (JSON documents), e.g. iam:PassRole for ECS task roles"
  type        = map(string)
  default     = {}
}

# --- Deployment configs --------------------------------------------------------

variable "deployment_configs" {
  description = "Custom deployment configs keyed by a short name. traffic_routing.type is AllAtOnce, TimeBasedCanary or TimeBasedLinear (ECS and Lambda); minimum_healthy_hosts is for Server"
  type = map(object({
    name             = optional(string)
    compute_platform = optional(string)
    minimum_healthy_hosts = optional(object({
      type  = string
      value = number
    }))
    traffic_routing = optional(object({
      type       = string
      interval   = optional(number)
      percentage = optional(number)
    }))
    zonal_config = optional(object({
      first_zone_monitor_duration_in_seconds = optional(number)
      monitor_duration_in_seconds            = optional(number)
      minimum_healthy_hosts_per_zone = optional(object({
        type  = string
        value = number
      }))
    }))
  }))
  default = {}
}

# --- Deployment groups ---------------------------------------------------------

variable "deployment_groups" {
  description = "Deployment groups keyed by a short name. For ECS set blue_green, ecs_services and load_balancer_info.target_group_pair (two target group names plus the production listener); deployment_style defaults to WITH_TRAFFIC_CONTROL / BLUE_GREEN. deployment_config_key refers to deployment_configs, otherwise deployment_config_name (e.g. CodeDeployDefault.ECSAllAtOnce)"
  type = map(object({
    name                   = optional(string)
    service_role_arn       = optional(string)
    deployment_config_name = optional(string)
    deployment_config_key  = optional(string)
    autoscaling_groups     = optional(list(string))

    deployment_style = optional(object({
      deployment_option = optional(string)
      deployment_type   = optional(string)
    }))

    blue_green = optional(object({
      deployment_ready_action_on_timeout    = optional(string, "CONTINUE_DEPLOYMENT")
      deployment_ready_wait_time_in_minutes = optional(number)
      green_fleet_provisioning_action       = optional(string)
      terminate_blue_action                 = optional(string, "TERMINATE")
      termination_wait_time_in_minutes      = optional(number, 5)
    }))

    ecs_services = optional(list(object({
      cluster_name = string
      service_name = string
    })), [])

    load_balancer_info = optional(object({
      elb_names          = optional(list(string), [])
      target_group_names = optional(list(string), [])
      target_group_pair = optional(object({
        target_group_names = list(string)
        prod_listener_arns = list(string)
        test_listener_arns = optional(list(string), [])
      }))
    }))

    auto_rollback = optional(object({
      enabled = optional(bool, true)
      events  = optional(list(string), ["DEPLOYMENT_FAILURE"])
    }), {})

    alarm_configuration = optional(object({
      alarms                    = optional(list(string))
      enabled                   = optional(bool)
      ignore_poll_alarm_failure = optional(bool)
    }))

    triggers = optional(list(object({
      name       = string
      events     = list(string)
      target_arn = string
    })), [])

    ec2_tag_filters = optional(list(object({
      key   = optional(string)
      type  = optional(string)
      value = optional(string)
    })), [])

    ec2_tag_sets = optional(list(list(object({
      key   = optional(string)
      type  = optional(string)
      value = optional(string)
    }))), [])

    on_premises_instance_tag_filters = optional(list(object({
      key   = optional(string)
      type  = optional(string)
      value = optional(string)
    })), [])

    outdated_instances_strategy = optional(string)
    termination_hook_enabled    = optional(bool)
    tags                        = optional(map(string), {})
  }))
  default = {}
}
