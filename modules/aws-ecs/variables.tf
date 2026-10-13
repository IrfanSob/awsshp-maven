# --- Cluster ----------------------------------------------------------------------

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "create_service_linked_role" {
  description = "Whether to create the AWS ECS service-linked role. Set false if ECS is already initialized in this account/region"
  type        = bool
  default     = false
}

variable "container_insights" {
  description = "Container Insights setting. Valid values: enabled, enhanced, disabled. Set null to leave unmanaged"
  type        = string
  default     = "enabled"
  nullable    = true

  validation {
    condition     = var.container_insights == null || contains(["enabled", "enhanced", "disabled"], coalesce(var.container_insights, "enabled"))
    error_message = "container_insights must be enabled, enhanced or disabled."
  }
}

# --- ECS Exec ---------------------------------------------------------------------

variable "enable_execute_command_configuration" {
  description = "Whether to manage the cluster ECS Exec configuration"
  type        = bool
  default     = false
}

variable "execute_command_kms_key_id" {
  description = "CMK used to encrypt the ECS Exec channel"
  type        = string
  default     = null
  nullable    = true
}

variable "execute_command_logging" {
  description = "ECS Exec logging mode. Valid values: NONE, DEFAULT, OVERRIDE"
  type        = string
  default     = "DEFAULT"

  validation {
    condition     = contains(["NONE", "DEFAULT", "OVERRIDE"], var.execute_command_logging)
    error_message = "execute_command_logging must be NONE, DEFAULT or OVERRIDE."
  }
}

variable "create_execute_command_log_group" {
  description = "Create a CloudWatch log group for ECS Exec sessions"
  type        = bool
  default     = false
}

variable "execute_command_log_group_name" {
  description = "ECS Exec log group name. Defaults to /aws/ecs/<cluster>/exec"
  type        = string
  default     = null
  nullable    = true
}

variable "execute_command_log_retention_in_days" {
  description = "Retention for the ECS Exec log group"
  type        = number
  default     = 30
}

variable "execute_command_log_group_kms_key_id" {
  description = "CMK ARN for the ECS Exec log group"
  type        = string
  default     = null
  nullable    = true
}

variable "execute_command_cloudwatch_encryption_enabled" {
  description = "Require encryption on the ECS Exec CloudWatch destination"
  type        = bool
  default     = false
}

variable "execute_command_s3_bucket_name" {
  description = "S3 bucket for ECS Exec session logs"
  type        = string
  default     = null
  nullable    = true
}

variable "execute_command_s3_key_prefix" {
  description = "Key prefix for ECS Exec session logs in S3"
  type        = string
  default     = null
  nullable    = true
}

variable "execute_command_s3_encryption_enabled" {
  description = "Require encryption on the ECS Exec S3 destination"
  type        = bool
  default     = false
}

# --- Service Connect --------------------------------------------------------------

variable "create_service_connect_namespace" {
  description = "Create a Cloud Map HTTP namespace and set it as the cluster Service Connect default"
  type        = bool
  default     = false
}

variable "service_connect_namespace_name" {
  description = "Namespace name, for example klikdokter.local"
  type        = string
  default     = null
  nullable    = true
}

variable "service_connect_namespace_description" {
  description = "Namespace description"
  type        = string
  default     = "Managed by Terraform"
}

variable "existing_service_connect_namespace_arn" {
  description = "Use an existing Cloud Map namespace ARN instead of creating one"
  type        = string
  default     = null
  nullable    = true
}

# --- Capacity providers -----------------------------------------------------------

variable "enable_fargate_capacity_provider" {
  description = "Attach the FARGATE capacity provider to the cluster"
  type        = bool
  default     = false
}

variable "enable_fargate_spot_capacity_provider" {
  description = "Attach the FARGATE_SPOT capacity provider to the cluster"
  type        = bool
  default     = false
}

variable "default_capacity_provider_strategy" {
  description = "Cluster default capacity provider strategy. Use the literal EC2 to refer to the capacity provider this module creates"
  type = list(object({
    capacity_provider = string
    base              = optional(number)
    weight            = optional(number)
  }))
  default = []
}

variable "create_ec2_capacity_provider" {
  description = "Create the launch template, Auto Scaling group and EC2 capacity provider"
  type        = bool
  default     = false
}

variable "ec2_capacity_provider_name" {
  description = "EC2 capacity provider name. Defaults to <cluster>-ec2-cp"
  type        = string
  default     = null
  nullable    = true
}

variable "ec2_ami_id" {
  description = "ECS optimized AMI for the container instances"
  type        = string
  default     = null
  nullable    = true
}

variable "ec2_instance_type" {
  description = "Container instance type"
  type        = string
  default     = "t3.medium"
}

variable "ec2_key_name" {
  description = "EC2 key pair name for the container instances"
  type        = string
  default     = null
  nullable    = true
}

# --- Container instance key pair ---------------------------------------------------
# Mirrors the key pair handling in aws-ec2-instances: generate the key, register it
# in EC2, and optionally drop both halves into S3. When ec2_create_key_pair is true
# the generated key takes precedence over ec2_key_name.

variable "ec2_create_key_pair" {
  description = "Generate an SSH key pair for the container instances and use it in the launch template"
  type        = bool
  default     = false
}

variable "ec2_key_pair_name" {
  description = "Name of the generated key pair. Defaults to <cluster>-ecs-node-keypair"
  type        = string
  default     = null
  nullable    = true
}

variable "ec2_key_algorithm" {
  description = "Algorithm for the generated key. RSA or ED25519"
  type        = string
  default     = "RSA"
}

variable "ec2_key_rsa_bits" {
  description = "Key size when ec2_key_algorithm is RSA"
  type        = number
  default     = 4096
}

variable "ec2_store_key_in_s3" {
  description = "Store the generated private and public key in S3"
  type        = bool
  default     = false
}

variable "ec2_ssh_key_bucket" {
  description = "S3 bucket that receives the generated key"
  type        = string
  default     = null
  nullable    = true
}

variable "ec2_ssh_key_prefix" {
  description = "Key prefix in the S3 bucket"
  type        = string
  default     = "ec2-keys"
}

variable "ec2_ssh_key_kms_key_id" {
  description = "KMS key for the S3 objects. Uses SSE-S3 when null"
  type        = string
  default     = null
  nullable    = true
}

variable "ec2_subnet_ids" {
  description = "Subnets the Auto Scaling group launches container instances into"
  type        = list(string)
  default     = []
}

variable "ec2_security_group_ids" {
  description = "Security groups attached to the container instances"
  type        = list(string)
  default     = []
}

variable "ec2_min_size" {
  description = "Minimum Auto Scaling group size"
  type        = number
  default     = 1
}

variable "ec2_max_size" {
  description = "Maximum Auto Scaling group size"
  type        = number
  default     = 3
}

variable "ec2_desired_capacity" {
  description = "Initial desired capacity. Ignored on subsequent applies so managed scaling can own it"
  type        = number
  default     = 1
}

variable "ec2_health_check_type" {
  description = "Auto Scaling group health check type. Valid values: EC2, ELB"
  type        = string
  default     = "EC2"
}

variable "ec2_health_check_grace_period" {
  description = "Auto Scaling group health check grace period in seconds"
  type        = number
  default     = 300
}

variable "ec2_default_cooldown" {
  description = "Auto Scaling group default cooldown in seconds"
  type        = number
  default     = 300
}

variable "ec2_capacity_rebalance" {
  description = "Enable capacity rebalance, useful with Spot container instances"
  type        = bool
  default     = false
}

variable "ec2_enable_instance_refresh" {
  description = "Roll instances automatically when the launch template changes"
  type        = bool
  default     = true
}

variable "ec2_instance_refresh_min_healthy_percentage" {
  description = "Minimum healthy percentage during an instance refresh"
  type        = number
  default     = 90
}

variable "ec2_managed_scaling_status" {
  description = "Managed scaling status. Valid values: ENABLED, DISABLED"
  type        = string
  default     = "ENABLED"
}

variable "ec2_managed_scaling_target_capacity" {
  description = "Managed scaling target capacity percentage"
  type        = number
  default     = 100
}

variable "ec2_managed_scaling_min_step" {
  description = "Minimum scaling step size"
  type        = number
  default     = 1
}

variable "ec2_managed_scaling_max_step" {
  description = "Maximum scaling step size"
  type        = number
  default     = 10
}

variable "ec2_managed_scaling_instance_warmup" {
  description = "Instance warmup period in seconds"
  type        = number
  default     = 300
}

variable "ec2_managed_termination_protection" {
  description = "Managed termination protection. ENABLED also sets protect_from_scale_in on the Auto Scaling group"
  type        = string
  default     = "DISABLED"

  validation {
    condition     = contains(["ENABLED", "DISABLED"], var.ec2_managed_termination_protection)
    error_message = "ec2_managed_termination_protection must be ENABLED or DISABLED."
  }
}

variable "ec2_managed_draining" {
  description = "Managed instance draining. Valid values: ENABLED, DISABLED"
  type        = string
  default     = "ENABLED"
}

variable "ec2_block_device_mappings" {
  description = "Root and extra volumes for the container instances"
  type = list(object({
    device_name           = string
    volume_size           = optional(number, 30)
    volume_type           = optional(string, "gp3")
    iops                  = optional(number)
    throughput            = optional(number)
    encrypted             = optional(bool, true)
    kms_key_id            = optional(string)
    delete_on_termination = optional(bool, true)
  }))
  default = []
}

variable "ec2_metadata_options" {
  description = "Instance metadata options for the container instances"
  type = object({
    http_endpoint               = optional(string, "enabled")
    http_tokens                 = optional(string, "required")
    http_put_response_hop_limit = optional(number, 2)
    instance_metadata_tags      = optional(string, "enabled")
  })
  default = {}
}

variable "ec2_enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring on the container instances"
  type        = bool
  default     = false
}

variable "ec2_ecs_agent_config" {
  description = "Extra key value pairs appended to /etc/ecs/ecs.config"
  type        = map(string)
  default     = {}
}

variable "ec2_additional_user_data_commands" {
  description = "Extra shell commands appended after the ECS agent configuration"
  type        = list(string)
  default     = []
}

variable "ec2_user_data_base64" {
  description = "Complete base64 user data. When set it replaces the generated ECS agent user data"
  type        = string
  default     = null
  nullable    = true
}

variable "ec2_launch_template_name" {
  description = "Launch template name. Defaults to <cluster>-ecs-lt"
  type        = string
  default     = null
  nullable    = true
}

variable "ec2_asg_name" {
  description = "Auto Scaling group name. Defaults to <cluster>-ecs-asg"
  type        = string
  default     = null
  nullable    = true
}

variable "ec2_instance_name" {
  description = "Name tag applied to container instances. Defaults to <cluster>-ecs-node"
  type        = string
  default     = null
  nullable    = true
}

variable "ec2_instance_tags" {
  description = "Extra tags applied to container instances through the launch template"
  type        = map(string)
  default     = {}
}

variable "ec2_asg_tags" {
  description = "Extra tags propagated by the Auto Scaling group"
  type        = map(string)
  default     = {}
}

# --- Container instance IAM -------------------------------------------------------

variable "create_ec2_instance_role" {
  description = "Create the container instance role and instance profile"
  type        = bool
  default     = true
}

variable "ec2_instance_role_name" {
  description = "Container instance role name. Defaults to <cluster>-ecs-instance-role"
  type        = string
  default     = null
  nullable    = true
}

variable "ec2_instance_profile_name" {
  description = "Container instance profile name. Defaults to <cluster>-ecs-instance-profile"
  type        = string
  default     = null
  nullable    = true
}

variable "ec2_existing_instance_profile_name" {
  description = "Existing instance profile to use when create_ec2_instance_role is false"
  type        = string
  default     = null
  nullable    = true
}

variable "ec2_instance_role_managed_policy_arns" {
  description = "Managed policies attached to the container instance role"
  type        = list(string)
  default = [
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
}

variable "ec2_instance_role_inline_policies" {
  description = "Inline policies for the container instance role, keyed by policy name"
  type        = map(string)
  default     = {}
}

# --- Task IAM ---------------------------------------------------------------------

variable "create_task_execution_role" {
  description = "Create the ECS task execution role used to pull images and write logs"
  type        = bool
  default     = true
}

variable "task_execution_role_name" {
  description = "Task execution role name. Defaults to <cluster>-task-execution-role"
  type        = string
  default     = null
  nullable    = true
}

variable "existing_task_execution_role_arn" {
  description = "Existing task execution role ARN when create_task_execution_role is false"
  type        = string
  default     = null
  nullable    = true
}

variable "task_execution_role_managed_policy_arns" {
  description = "Managed policies attached to the task execution role"
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}

variable "task_execution_role_inline_policies" {
  description = "Inline policies for the task execution role, for example Secrets Manager or SSM Parameter Store reads"
  type        = map(string)
  default     = {}
}

variable "create_task_role" {
  description = "Create the ECS task role used by the application itself"
  type        = bool
  default     = false
}

variable "task_role_name" {
  description = "Task role name. Defaults to <cluster>-task-role"
  type        = string
  default     = null
  nullable    = true
}

variable "existing_task_role_arn" {
  description = "Existing task role ARN when create_task_role is false"
  type        = string
  default     = null
  nullable    = true
}

variable "task_role_managed_policy_arns" {
  description = "Managed policies attached to the task role"
  type        = list(string)
  default     = []
}

variable "task_role_inline_policies" {
  description = "Inline policies for the task role, keyed by policy name"
  type        = map(string)
  default     = {}
}

# --- Task definitions and services ------------------------------------------------

variable "task_log_groups" {
  description = "CloudWatch log groups to create for tasks, keyed by log group name"
  type = map(object({
    retention_in_days = optional(number, 30)
    kms_key_id        = optional(string)
    tags              = optional(map(string), {})
  }))
  default = {}
}

variable "task_definitions" {
  description = "Task definitions to create, keyed by a short name. Leave empty when a CI/CD pipeline owns them"
  type = map(object({
    family                     = optional(string)
    cpu                        = optional(string)
    memory                     = optional(string)
    network_mode               = optional(string, "awsvpc")
    requires_compatibilities   = optional(list(string), ["EC2"])
    container_definitions_json = string
    execution_role_arn         = optional(string)
    task_role_arn              = optional(string)
    ipc_mode                   = optional(string)
    pid_mode                   = optional(string)
    skip_destroy               = optional(bool, false)

    runtime_platform = optional(object({
      operating_system_family = optional(string)
      cpu_architecture        = optional(string)
    }))

    volumes = optional(list(object({
      name      = string
      host_path = optional(string)

      efs_volume_configuration = optional(object({
        file_system_id          = string
        root_directory          = optional(string)
        transit_encryption      = optional(string)
        transit_encryption_port = optional(number)

        authorization_config = optional(object({
          access_point_id = optional(string)
          iam             = optional(string)
        }))
      }))
    })), [])

    placement_constraints = optional(list(object({
      type       = string
      expression = optional(string)
    })), [])

    tags = optional(map(string), {})
  }))
  default = {}
}

variable "services" {
  description = "ECS services to create, keyed by a short name. Leave empty when a CI/CD pipeline owns them. deployment_controller_type is ECS, CODE_DEPLOY or EXTERNAL; null keeps the AWS default (ECS) without writing the block. CODE_DEPLOY is required for CodeDeploy blue/green and cannot be combined with deployment_circuit_breaker"
  type = map(object({
    name                = optional(string)
    task_definition_key = optional(string)
    task_definition_arn = optional(string)

    desired_count       = optional(number, 1)
    launch_type         = optional(string)
    platform_version    = optional(string)
    scheduling_strategy = optional(string, "REPLICA")

    enable_execute_command            = optional(bool, false)
    enable_ecs_managed_tags           = optional(bool, true)
    propagate_tags                    = optional(string)
    health_check_grace_period_seconds = optional(number)
    force_new_deployment              = optional(bool)
    wait_for_steady_state             = optional(bool, false)

    deployment_minimum_healthy_percent = optional(number)
    deployment_maximum_percent         = optional(number)

    deployment_controller_type = optional(string)

    deployment_circuit_breaker = optional(object({
      enable   = bool
      rollback = bool
    }))

    capacity_provider_strategy = optional(list(object({
      capacity_provider = string
      base              = optional(number)
      weight            = optional(number)
    })), [])

    network_configuration = optional(object({
      subnets          = list(string)
      security_groups  = optional(list(string))
      assign_public_ip = optional(bool, false)
    }))

    load_balancers = optional(list(object({
      target_group_arn = string
      container_name   = string
      container_port   = number
    })), [])

    service_registries = optional(object({
      registry_arn   = string
      port           = optional(number)
      container_name = optional(string)
      container_port = optional(number)
    }))

    service_connect = optional(object({
      enabled   = optional(bool, true)
      namespace = optional(string)

      services = optional(list(object({
        port_name             = string
        discovery_name        = optional(string)
        ingress_port_override = optional(number)

        client_alias = optional(object({
          port     = number
          dns_name = optional(string)
        }))
      })), [])
    }))

    ordered_placement_strategies = optional(list(object({
      type  = string
      field = optional(string)
    })), [])

    placement_constraints = optional(list(object({
      type       = string
      expression = optional(string)
    })), [])

    autoscaling = optional(object({
      min_capacity = number
      max_capacity = number

      policies = map(object({
        predefined_metric_type = string
        target_value           = number
        resource_label         = optional(string)
        scale_in_cooldown      = optional(number, 300)
        scale_out_cooldown     = optional(number, 60)
        disable_scale_in       = optional(bool, false)
      }))
    }))

    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for key, service in var.services :
      service.task_definition_key != null || service.task_definition_arn != null
    ])
    error_message = "Each service must set either task_definition_key or task_definition_arn."
  }

  validation {
    condition = alltrue([
      for key, service in var.services :
      contains(["ECS", "CODE_DEPLOY", "EXTERNAL"], coalesce(service.deployment_controller_type, "ECS"))
    ])
    error_message = "deployment_controller_type must be one of: ECS, CODE_DEPLOY, EXTERNAL."
  }
}
