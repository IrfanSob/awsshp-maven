# Reusable ECS module.
# Covers the cluster, its capacity providers on Fargate and on an EC2 Auto Scaling
# group, the Service Connect namespace, the usual IAM roles, and optionally task
# definitions and services. Everything past the cluster is behind a flag, so the
# module can stop at "cluster ready for a CI/CD pipeline to deploy into".

data "aws_caller_identity" "current" {}

locals {
  cluster_name = var.cluster_name

  # ECS agent settings written into /etc/ecs/ecs.config on each container instance.
  ecs_agent_config = merge(
    {
      ECS_CLUSTER                   = var.cluster_name
      ECS_ENABLE_CONTAINER_METADATA = "true"
    },
    var.ec2_ecs_agent_config
  )

  ecs_agent_user_data = join("\n", concat(
    ["#!/bin/bash"],
    [for key, value in local.ecs_agent_config : "echo \"${key}=${value}\" >> /etc/ecs/ecs.config"],
    var.ec2_additional_user_data_commands
  ))

  ec2_user_data_base64 = var.ec2_user_data_base64 != null ? var.ec2_user_data_base64 : base64encode(local.ecs_agent_user_data)

  ec2_capacity_provider_name = var.ec2_capacity_provider_name != null ? var.ec2_capacity_provider_name : "${var.cluster_name}-ec2-cp"

  ec2_key_pair_name = var.ec2_key_pair_name != null ? var.ec2_key_pair_name : "${var.cluster_name}-ecs-node-keypair"
  create_key_pair   = var.create_ec2_capacity_provider && var.ec2_create_key_pair

  # Fargate providers are named by AWS, the EC2 one by this module.
  fargate_capacity_providers = compact([
    var.enable_fargate_capacity_provider ? "FARGATE" : "",
    var.enable_fargate_spot_capacity_provider ? "FARGATE_SPOT" : ""
  ])

  all_capacity_providers = concat(
    local.fargate_capacity_providers,
    var.create_ec2_capacity_provider ? [local.ec2_capacity_provider_name] : []
  )

  instance_profile_name = var.create_ec2_instance_role ? one(aws_iam_instance_profile.ec2[*].name) : var.ec2_existing_instance_profile_name

  task_execution_role_arn = var.create_task_execution_role ? one(aws_iam_role.task_execution[*].arn) : var.existing_task_execution_role_arn
  task_role_arn           = var.create_task_role ? one(aws_iam_role.task[*].arn) : var.existing_task_role_arn

  service_connect_namespace_arn = var.create_service_connect_namespace ? one(aws_service_discovery_http_namespace.this[*].arn) : var.existing_service_connect_namespace_arn
}

# --- Cluster ----------------------------------------------------------------------

# Service-linked role for ECS. On an account/region where ECS has never been used,
# CreateCluster can outrun the implicit auto-creation of this role and fail with
# "ECS Service Linked Role is not ready". Creating it explicitly first avoids the
# race. Set create_service_linked_role = false if ECS was already initialized.
resource "aws_iam_service_linked_role" "ecs" {
  count = var.create_service_linked_role ? 1 : 0

  aws_service_name = "ecs.amazonaws.com"
}

resource "aws_service_discovery_http_namespace" "this" {
  count = var.create_service_connect_namespace ? 1 : 0

  name        = var.service_connect_namespace_name
  description = var.service_connect_namespace_description

  tags = merge(
    var.tags,
    {
      Name = var.service_connect_namespace_name
    }
  )
}

resource "aws_cloudwatch_log_group" "exec" {
  count = var.create_execute_command_log_group ? 1 : 0

  name              = var.execute_command_log_group_name != null ? var.execute_command_log_group_name : "/aws/ecs/${var.cluster_name}/exec"
  retention_in_days = var.execute_command_log_retention_in_days
  kms_key_id        = var.execute_command_log_group_kms_key_id

  tags = merge(
    var.tags,
    {
      Name = var.execute_command_log_group_name != null ? var.execute_command_log_group_name : "/aws/ecs/${var.cluster_name}/exec"
    }
  )
}

resource "aws_ecs_cluster" "this" {
  name = local.cluster_name

  dynamic "setting" {
    for_each = var.container_insights != null ? [1] : []

    content {
      name  = "containerInsights"
      value = var.container_insights
    }
  }

  dynamic "configuration" {
    for_each = var.enable_execute_command_configuration ? [1] : []

    content {
      execute_command_configuration {
        kms_key_id = var.execute_command_kms_key_id
        logging    = var.execute_command_logging

        dynamic "log_configuration" {
          for_each = var.execute_command_logging == "OVERRIDE" ? [1] : []

          content {
            cloud_watch_encryption_enabled = var.execute_command_cloudwatch_encryption_enabled
            cloud_watch_log_group_name     = var.create_execute_command_log_group ? aws_cloudwatch_log_group.exec[0].name : var.execute_command_log_group_name
            s3_bucket_name                 = var.execute_command_s3_bucket_name
            s3_key_prefix                  = var.execute_command_s3_key_prefix
            s3_bucket_encryption_enabled   = var.execute_command_s3_encryption_enabled
          }
        }
      }
    }
  }

  # The condition uses variables rather than the namespace ARN, which is unknown at
  # plan time on the first apply and would make the block count undecidable.
  dynamic "service_connect_defaults" {
    for_each = var.create_service_connect_namespace || var.existing_service_connect_namespace_arn != null ? [1] : []

    content {
      namespace = local.service_connect_namespace_arn
    }
  }

  tags = merge(
    var.tags,
    {
      Name = local.cluster_name
    }
  )

  # Service Connect defaults are often repointed from the console or a pipeline.
  lifecycle {
    ignore_changes = [service_connect_defaults]
  }

  depends_on = [aws_iam_service_linked_role.ecs]
}

# --- EC2 capacity provider --------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume_role" {
  count = var.create_ec2_instance_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  count = var.create_ec2_instance_role ? 1 : 0

  name               = var.ec2_instance_role_name != null ? var.ec2_instance_role_name : "${var.cluster_name}-ecs-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role[0].json

  tags = merge(
    var.tags,
    {
      Name = var.ec2_instance_role_name != null ? var.ec2_instance_role_name : "${var.cluster_name}-ecs-instance-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ec2_managed" {
  for_each = var.create_ec2_instance_role ? toset(var.ec2_instance_role_managed_policy_arns) : []

  role       = aws_iam_role.ec2[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "ec2_inline" {
  for_each = var.create_ec2_instance_role ? var.ec2_instance_role_inline_policies : {}

  name   = each.key
  role   = aws_iam_role.ec2[0].id
  policy = each.value
}

resource "aws_iam_instance_profile" "ec2" {
  count = var.create_ec2_instance_role ? 1 : 0

  name = var.ec2_instance_profile_name != null ? var.ec2_instance_profile_name : "${var.cluster_name}-ecs-instance-profile"
  role = aws_iam_role.ec2[0].name

  tags = var.tags
}

# Container instance key pair, stored in S3 the same way aws-ec2-instances does it.
resource "tls_private_key" "ec2" {
  count = local.create_key_pair ? 1 : 0

  algorithm = var.ec2_key_algorithm
  rsa_bits  = var.ec2_key_algorithm == "RSA" ? var.ec2_key_rsa_bits : null
}

resource "aws_key_pair" "ec2" {
  count = local.create_key_pair ? 1 : 0

  key_name   = local.ec2_key_pair_name
  public_key = tls_private_key.ec2[0].public_key_openssh

  tags = merge(
    var.tags,
    {
      Name = local.ec2_key_pair_name
    }
  )
}

resource "aws_s3_object" "ec2_private_key" {
  count = local.create_key_pair && var.ec2_store_key_in_s3 && var.ec2_ssh_key_bucket != null ? 1 : 0

  bucket  = var.ec2_ssh_key_bucket
  key     = "${var.ec2_ssh_key_prefix}/${local.ec2_key_pair_name}.pem"
  content = tls_private_key.ec2[0].private_key_pem

  server_side_encryption = var.ec2_ssh_key_kms_key_id != null ? "aws:kms" : "AES256"
  kms_key_id             = var.ec2_ssh_key_kms_key_id

  content_type = "text/plain"

  tags = merge(
    var.tags,
    {
      Name = "${local.ec2_key_pair_name}-private-key"
    }
  )
}

resource "aws_s3_object" "ec2_public_key" {
  count = local.create_key_pair && var.ec2_store_key_in_s3 && var.ec2_ssh_key_bucket != null ? 1 : 0

  bucket  = var.ec2_ssh_key_bucket
  key     = "${var.ec2_ssh_key_prefix}/${local.ec2_key_pair_name}.pub"
  content = tls_private_key.ec2[0].public_key_openssh

  server_side_encryption = var.ec2_ssh_key_kms_key_id != null ? "aws:kms" : "AES256"
  kms_key_id             = var.ec2_ssh_key_kms_key_id

  content_type = "text/plain"

  tags = merge(
    var.tags,
    {
      Name = "${local.ec2_key_pair_name}-public-key"
    }
  )
}

resource "aws_launch_template" "ec2" {
  count = var.create_ec2_capacity_provider ? 1 : 0

  name          = var.ec2_launch_template_name != null ? var.ec2_launch_template_name : "${var.cluster_name}-ecs-lt"
  description   = "Launch template for ${var.cluster_name} ECS container instances"
  image_id      = var.ec2_ami_id
  instance_type = var.ec2_instance_type
  key_name      = local.create_key_pair ? aws_key_pair.ec2[0].key_name : var.ec2_key_name
  user_data     = local.ec2_user_data_base64

  update_default_version = true

  vpc_security_group_ids = var.ec2_security_group_ids

  dynamic "iam_instance_profile" {
    for_each = var.create_ec2_instance_role || var.ec2_existing_instance_profile_name != null ? [1] : []

    content {
      name = local.instance_profile_name
    }
  }

  dynamic "block_device_mappings" {
    for_each = var.ec2_block_device_mappings

    content {
      device_name = block_device_mappings.value.device_name

      ebs {
        volume_size           = block_device_mappings.value.volume_size
        volume_type           = block_device_mappings.value.volume_type
        iops                  = block_device_mappings.value.iops
        throughput            = block_device_mappings.value.throughput
        encrypted             = block_device_mappings.value.encrypted
        kms_key_id            = block_device_mappings.value.kms_key_id
        delete_on_termination = block_device_mappings.value.delete_on_termination
      }
    }
  }

  metadata_options {
    http_endpoint               = var.ec2_metadata_options.http_endpoint
    http_tokens                 = var.ec2_metadata_options.http_tokens
    http_put_response_hop_limit = var.ec2_metadata_options.http_put_response_hop_limit
    instance_metadata_tags      = var.ec2_metadata_options.instance_metadata_tags
  }

  monitoring {
    enabled = var.ec2_enable_detailed_monitoring
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.tags,
      var.ec2_instance_tags,
      {
        Name = var.ec2_instance_name != null ? var.ec2_instance_name : "${var.cluster_name}-ecs-node"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      var.tags,
      {
        Name = var.ec2_instance_name != null ? var.ec2_instance_name : "${var.cluster_name}-ecs-node"
      }
    )
  }

  tags = merge(
    var.tags,
    {
      Name = var.ec2_launch_template_name != null ? var.ec2_launch_template_name : "${var.cluster_name}-ecs-lt"
    }
  )
}

resource "aws_autoscaling_group" "ec2" {
  count = var.create_ec2_capacity_provider ? 1 : 0

  name                = var.ec2_asg_name != null ? var.ec2_asg_name : "${var.cluster_name}-ecs-asg"
  vpc_zone_identifier = var.ec2_subnet_ids

  min_size         = var.ec2_min_size
  max_size         = var.ec2_max_size
  desired_capacity = var.ec2_desired_capacity

  health_check_type         = var.ec2_health_check_type
  health_check_grace_period = var.ec2_health_check_grace_period
  default_cooldown          = var.ec2_default_cooldown
  capacity_rebalance        = var.ec2_capacity_rebalance

  # Managed termination protection on the capacity provider requires this.
  protect_from_scale_in = var.ec2_managed_termination_protection == "ENABLED"

  launch_template {
    id      = aws_launch_template.ec2[0].id
    version = "$Latest"
  }

  dynamic "instance_refresh" {
    for_each = var.ec2_enable_instance_refresh ? [1] : []

    content {
      strategy = "Rolling"

      preferences {
        min_healthy_percentage = var.ec2_instance_refresh_min_healthy_percentage
      }
    }
  }

  dynamic "tag" {
    for_each = merge(
      var.tags,
      var.ec2_asg_tags,
      {
        Name             = var.ec2_instance_name != null ? var.ec2_instance_name : "${var.cluster_name}-ecs-node"
        AmazonECSManaged = "true"
      }
    )

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_ecs_capacity_provider" "ec2" {
  count = var.create_ec2_capacity_provider ? 1 : 0

  name = local.ec2_capacity_provider_name

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ec2[0].arn
    managed_termination_protection = var.ec2_managed_termination_protection
    managed_draining               = var.ec2_managed_draining

    managed_scaling {
      status                    = var.ec2_managed_scaling_status
      target_capacity           = var.ec2_managed_scaling_target_capacity
      minimum_scaling_step_size = var.ec2_managed_scaling_min_step
      maximum_scaling_step_size = var.ec2_managed_scaling_max_step
      instance_warmup_period    = var.ec2_managed_scaling_instance_warmup
    }
  }

  tags = merge(
    var.tags,
    {
      Name = local.ec2_capacity_provider_name
    }
  )
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  count = length(local.all_capacity_providers) > 0 ? 1 : 0

  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = local.all_capacity_providers

  dynamic "default_capacity_provider_strategy" {
    for_each = var.default_capacity_provider_strategy

    content {
      capacity_provider = default_capacity_provider_strategy.value.capacity_provider == "EC2" ? local.ec2_capacity_provider_name : default_capacity_provider_strategy.value.capacity_provider
      base              = default_capacity_provider_strategy.value.base
      weight            = default_capacity_provider_strategy.value.weight
    }
  }

  # capacity_providers is built from the provider NAME (a local string), which
  # gives Terraform no dependency on the resource itself -- without this the
  # association can run before the capacity provider exists and fail with
  # "The specified capacity provider was not found".
  depends_on = [aws_ecs_capacity_provider.ec2]

  # Both are left to whoever operates the cluster day to day. Adding a capacity
  # provider from the console will not be reverted, and Terraform will not push a
  # changed list either, so a later change here has to be applied by hand.
  lifecycle {
    ignore_changes = [
      capacity_providers,
      default_capacity_provider_strategy
    ]
  }
}

# --- Task IAM roles ---------------------------------------------------------------

data "aws_iam_policy_document" "task_assume_role" {
  count = var.create_task_execution_role || var.create_task_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  count = var.create_task_execution_role ? 1 : 0

  name               = var.task_execution_role_name != null ? var.task_execution_role_name : "${var.cluster_name}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume_role[0].json

  tags = merge(
    var.tags,
    {
      Name = var.task_execution_role_name != null ? var.task_execution_role_name : "${var.cluster_name}-task-execution-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  for_each = var.create_task_execution_role ? toset(var.task_execution_role_managed_policy_arns) : []

  role       = aws_iam_role.task_execution[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "task_execution_inline" {
  for_each = var.create_task_execution_role ? var.task_execution_role_inline_policies : {}

  name   = each.key
  role   = aws_iam_role.task_execution[0].id
  policy = each.value
}

resource "aws_iam_role" "task" {
  count = var.create_task_role ? 1 : 0

  name               = var.task_role_name != null ? var.task_role_name : "${var.cluster_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume_role[0].json

  tags = merge(
    var.tags,
    {
      Name = var.task_role_name != null ? var.task_role_name : "${var.cluster_name}-task-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "task_managed" {
  for_each = var.create_task_role ? toset(var.task_role_managed_policy_arns) : []

  role       = aws_iam_role.task[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "task_inline" {
  for_each = var.create_task_role ? var.task_role_inline_policies : {}

  name   = each.key
  role   = aws_iam_role.task[0].id
  policy = each.value
}

# --- Task definitions -------------------------------------------------------------

resource "aws_cloudwatch_log_group" "tasks" {
  for_each = var.task_log_groups

  name              = each.key
  retention_in_days = each.value.retention_in_days
  kms_key_id        = each.value.kms_key_id

  tags = merge(
    var.tags,
    each.value.tags,
    {
      Name = each.key
    }
  )
}

resource "aws_ecs_task_definition" "this" {
  for_each = var.task_definitions

  family                   = coalesce(each.value.family, each.key)
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  network_mode             = each.value.network_mode
  requires_compatibilities = each.value.requires_compatibilities
  container_definitions    = each.value.container_definitions_json
  ipc_mode                 = each.value.ipc_mode
  pid_mode                 = each.value.pid_mode
  skip_destroy             = each.value.skip_destroy

  execution_role_arn = try(coalesce(each.value.execution_role_arn, local.task_execution_role_arn), null)
  task_role_arn      = try(coalesce(each.value.task_role_arn, local.task_role_arn), null)

  dynamic "runtime_platform" {
    for_each = each.value.runtime_platform != null ? [each.value.runtime_platform] : []

    content {
      operating_system_family = runtime_platform.value.operating_system_family
      cpu_architecture        = runtime_platform.value.cpu_architecture
    }
  }

  dynamic "volume" {
    for_each = each.value.volumes

    content {
      name      = volume.value.name
      host_path = volume.value.host_path

      dynamic "efs_volume_configuration" {
        for_each = volume.value.efs_volume_configuration != null ? [volume.value.efs_volume_configuration] : []

        content {
          file_system_id          = efs_volume_configuration.value.file_system_id
          root_directory          = efs_volume_configuration.value.root_directory
          transit_encryption      = efs_volume_configuration.value.transit_encryption
          transit_encryption_port = efs_volume_configuration.value.transit_encryption_port

          dynamic "authorization_config" {
            for_each = efs_volume_configuration.value.authorization_config != null ? [efs_volume_configuration.value.authorization_config] : []

            content {
              access_point_id = authorization_config.value.access_point_id
              iam             = authorization_config.value.iam
            }
          }
        }
      }
    }
  }

  dynamic "placement_constraints" {
    for_each = each.value.placement_constraints

    content {
      type       = placement_constraints.value.type
      expression = placement_constraints.value.expression
    }
  }

  tags = merge(
    var.tags,
    each.value.tags,
    {
      Name = coalesce(each.value.family, each.key)
    }
  )
}

# --- Services ---------------------------------------------------------------------

resource "aws_ecs_service" "this" {
  for_each = var.services

  name            = coalesce(each.value.name, each.key)
  cluster         = aws_ecs_cluster.this.arn
  task_definition = each.value.task_definition_arn != null ? each.value.task_definition_arn : aws_ecs_task_definition.this[each.value.task_definition_key].arn

  desired_count                      = each.value.desired_count
  launch_type                        = length(each.value.capacity_provider_strategy) > 0 ? null : each.value.launch_type
  platform_version                   = each.value.platform_version
  scheduling_strategy                = each.value.scheduling_strategy
  enable_execute_command             = each.value.enable_execute_command
  enable_ecs_managed_tags            = each.value.enable_ecs_managed_tags
  propagate_tags                     = each.value.propagate_tags
  health_check_grace_period_seconds  = each.value.health_check_grace_period_seconds
  force_new_deployment               = each.value.force_new_deployment
  wait_for_steady_state              = each.value.wait_for_steady_state
  deployment_minimum_healthy_percent = each.value.deployment_minimum_healthy_percent
  deployment_maximum_percent         = each.value.deployment_maximum_percent

  dynamic "capacity_provider_strategy" {
    for_each = each.value.capacity_provider_strategy

    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider == "EC2" ? local.ec2_capacity_provider_name : capacity_provider_strategy.value.capacity_provider
      base              = capacity_provider_strategy.value.base
      weight            = capacity_provider_strategy.value.weight
    }
  }

  dynamic "deployment_controller" {
    for_each = each.value.deployment_controller_type != null ? [1] : []

    content {
      type = each.value.deployment_controller_type
    }
  }

  dynamic "deployment_circuit_breaker" {
    for_each = each.value.deployment_circuit_breaker != null ? [each.value.deployment_circuit_breaker] : []

    content {
      enable   = deployment_circuit_breaker.value.enable
      rollback = deployment_circuit_breaker.value.rollback
    }
  }

  dynamic "network_configuration" {
    for_each = each.value.network_configuration != null ? [each.value.network_configuration] : []

    content {
      subnets          = network_configuration.value.subnets
      security_groups  = network_configuration.value.security_groups
      assign_public_ip = network_configuration.value.assign_public_ip
    }
  }

  dynamic "load_balancer" {
    for_each = each.value.load_balancers

    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  dynamic "service_registries" {
    for_each = each.value.service_registries != null ? [each.value.service_registries] : []

    content {
      registry_arn   = service_registries.value.registry_arn
      port           = service_registries.value.port
      container_name = service_registries.value.container_name
      container_port = service_registries.value.container_port
    }
  }

  dynamic "service_connect_configuration" {
    for_each = each.value.service_connect != null ? [each.value.service_connect] : []

    content {
      enabled   = service_connect_configuration.value.enabled
      namespace = coalesce(service_connect_configuration.value.namespace, local.service_connect_namespace_arn)

      dynamic "service" {
        for_each = service_connect_configuration.value.services

        content {
          port_name             = service.value.port_name
          discovery_name        = service.value.discovery_name
          ingress_port_override = service.value.ingress_port_override

          dynamic "client_alias" {
            for_each = service.value.client_alias != null ? [service.value.client_alias] : []

            content {
              port     = client_alias.value.port
              dns_name = client_alias.value.dns_name
            }
          }
        }
      }
    }
  }

  dynamic "ordered_placement_strategy" {
    for_each = each.value.ordered_placement_strategies

    content {
      type  = ordered_placement_strategy.value.type
      field = ordered_placement_strategy.value.field
    }
  }

  dynamic "placement_constraints" {
    for_each = each.value.placement_constraints

    content {
      type       = placement_constraints.value.type
      expression = placement_constraints.value.expression
    }
  }

  tags = merge(
    var.tags,
    each.value.tags,
    {
      Name = coalesce(each.value.name, each.key)
    }
  )

  # Everything a deployment pipeline or the console normally rewrites. Terraform
  # creates the service once and then leaves these to the pipeline.
  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count,
      capacity_provider_strategy,
      load_balancer
    ]

    precondition {
      condition     = !contains(["CODE_DEPLOY", "EXTERNAL"], coalesce(each.value.deployment_controller_type, "ECS")) || each.value.deployment_circuit_breaker == null
      error_message = "deployment_circuit_breaker is only supported with the ECS deployment controller."
    }
  }
}

# --- Service auto scaling ---------------------------------------------------------

locals {
  autoscaled_services = {
    for key, service in var.services : key => service
    if service.autoscaling != null
  }

  autoscaling_policies = merge([
    for key, service in local.autoscaled_services : {
      for policy_name, policy in service.autoscaling.policies :
      "${key}.${policy_name}" => {
        service_key = key
        policy_name = policy_name
        policy      = policy
      }
    }
  ]...)
}

resource "aws_appautoscaling_target" "this" {
  for_each = local.autoscaled_services

  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = each.value.autoscaling.min_capacity
  max_capacity       = each.value.autoscaling.max_capacity

  tags = var.tags
}

resource "aws_appautoscaling_policy" "this" {
  for_each = local.autoscaling_policies

  name               = "${aws_ecs_service.this[each.value.service_key].name}-${each.value.policy_name}"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this[each.value.service_key].service_namespace
  resource_id        = aws_appautoscaling_target.this[each.value.service_key].resource_id
  scalable_dimension = aws_appautoscaling_target.this[each.value.service_key].scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = each.value.policy.target_value
    scale_in_cooldown  = each.value.policy.scale_in_cooldown
    scale_out_cooldown = each.value.policy.scale_out_cooldown
    disable_scale_in   = each.value.policy.disable_scale_in

    predefined_metric_specification {
      predefined_metric_type = each.value.policy.predefined_metric_type
      resource_label         = each.value.policy.resource_label
    }
  }
}
