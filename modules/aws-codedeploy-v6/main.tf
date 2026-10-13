# Reusable CodeDeploy module.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

data "aws_partition" "current" {}

locals {
  is_ecs = var.compute_platform == "ECS"

  default_service_role_policy = {
    ECS    = "service-role/AWSCodeDeployRoleForECS"
    Server = "service-role/AWSCodeDeployRole"
    Lambda = "service-role/AWSCodeDeployRoleForLambda"
  }

  service_role_arn = var.create_service_role ? one(aws_iam_role.this[*].arn) : var.service_role_arn

  application_name = var.create_application ? one(aws_codedeploy_app.this[*].name) : var.application_name
}

# Application
resource "aws_codedeploy_app" "this" {
  count = var.create_application ? 1 : 0

  name             = var.application_name
  compute_platform = var.compute_platform

  tags = merge(
    var.tags,
    { Name = var.application_name }
  )
}

# Service Role (toggle: create_service_role)
data "aws_iam_policy_document" "assume_role" {
  count = var.create_service_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  count = var.create_service_role ? 1 : 0

  name                 = coalesce(var.service_role_name, "${var.application_name}-codedeploy-role")
  path                 = var.service_role_path
  permissions_boundary = var.service_role_permissions_boundary
  assume_role_policy   = data.aws_iam_policy_document.assume_role[0].json

  tags = merge(
    var.tags,
    { Name = coalesce(var.service_role_name, "${var.application_name}-codedeploy-role") }
  )
}

resource "aws_iam_role_policy_attachment" "default" {
  count = var.create_service_role && var.attach_default_service_role_policy ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${local.default_service_role_policy[var.compute_platform]}"
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = var.create_service_role ? toset(var.service_role_managed_policy_arns) : toset([])

  role       = aws_iam_role.this[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  for_each = var.create_service_role ? var.service_role_inline_policies : {}

  name   = each.key
  role   = aws_iam_role.this[0].id
  policy = each.value
}

# Custom Deployment Configs
resource "aws_codedeploy_deployment_config" "this" {
  for_each = var.deployment_configs

  deployment_config_name = coalesce(each.value.name, "${var.application_name}-${each.key}")
  compute_platform       = coalesce(each.value.compute_platform, var.compute_platform)

  dynamic "minimum_healthy_hosts" {
    for_each = each.value.minimum_healthy_hosts != null ? [each.value.minimum_healthy_hosts] : []

    content {
      type  = minimum_healthy_hosts.value.type
      value = minimum_healthy_hosts.value.value
    }
  }

  dynamic "traffic_routing_config" {
    for_each = each.value.traffic_routing != null ? [each.value.traffic_routing] : []

    content {
      type = traffic_routing_config.value.type

      dynamic "time_based_canary" {
        for_each = traffic_routing_config.value.type == "TimeBasedCanary" ? [1] : []

        content {
          interval   = traffic_routing_config.value.interval
          percentage = traffic_routing_config.value.percentage
        }
      }

      dynamic "time_based_linear" {
        for_each = traffic_routing_config.value.type == "TimeBasedLinear" ? [1] : []

        content {
          interval   = traffic_routing_config.value.interval
          percentage = traffic_routing_config.value.percentage
        }
      }
    }
  }

  dynamic "zonal_config" {
    for_each = each.value.zonal_config != null ? [each.value.zonal_config] : []

    content {
      first_zone_monitor_duration_in_seconds = zonal_config.value.first_zone_monitor_duration_in_seconds
      monitor_duration_in_seconds            = zonal_config.value.monitor_duration_in_seconds

      dynamic "minimum_healthy_hosts_per_zone" {
        for_each = zonal_config.value.minimum_healthy_hosts_per_zone != null ? [zonal_config.value.minimum_healthy_hosts_per_zone] : []

        content {
          type  = minimum_healthy_hosts_per_zone.value.type
          value = minimum_healthy_hosts_per_zone.value.value
        }
      }
    }
  }
}

# Deployment Groups
resource "aws_codedeploy_deployment_group" "this" {
  for_each = var.deployment_groups

  app_name               = local.application_name
  deployment_group_name  = coalesce(each.value.name, each.key)
  service_role_arn       = coalesce(each.value.service_role_arn, local.service_role_arn)
  deployment_config_name = each.value.deployment_config_key != null ? aws_codedeploy_deployment_config.this[each.value.deployment_config_key].deployment_config_name : each.value.deployment_config_name
  autoscaling_groups     = each.value.autoscaling_groups

  outdated_instances_strategy = each.value.outdated_instances_strategy
  termination_hook_enabled    = each.value.termination_hook_enabled

  dynamic "deployment_style" {
    for_each = each.value.deployment_style != null || local.is_ecs ? [1] : []

    content {
      deployment_option = try(coalesce(try(each.value.deployment_style.deployment_option, null), local.is_ecs ? "WITH_TRAFFIC_CONTROL" : null), null)
      deployment_type   = try(coalesce(try(each.value.deployment_style.deployment_type, null), local.is_ecs ? "BLUE_GREEN" : null), null)
    }
  }

  dynamic "blue_green_deployment_config" {
    for_each = each.value.blue_green != null ? [each.value.blue_green] : []

    content {
      deployment_ready_option {
        action_on_timeout    = blue_green_deployment_config.value.deployment_ready_action_on_timeout
        wait_time_in_minutes = blue_green_deployment_config.value.deployment_ready_wait_time_in_minutes
      }

      dynamic "green_fleet_provisioning_option" {
        for_each = blue_green_deployment_config.value.green_fleet_provisioning_action != null ? [1] : []

        content {
          action = blue_green_deployment_config.value.green_fleet_provisioning_action
        }
      }

      terminate_blue_instances_on_deployment_success {
        action                           = blue_green_deployment_config.value.terminate_blue_action
        termination_wait_time_in_minutes = blue_green_deployment_config.value.termination_wait_time_in_minutes
      }
    }
  }

  dynamic "ecs_service" {
    for_each = each.value.ecs_services

    content {
      cluster_name = ecs_service.value.cluster_name
      service_name = ecs_service.value.service_name
    }
  }

  dynamic "load_balancer_info" {
    for_each = each.value.load_balancer_info != null ? [each.value.load_balancer_info] : []

    content {
      dynamic "elb_info" {
        for_each = load_balancer_info.value.elb_names

        content {
          name = elb_info.value
        }
      }

      dynamic "target_group_info" {
        for_each = load_balancer_info.value.target_group_names

        content {
          name = target_group_info.value
        }
      }

      dynamic "target_group_pair_info" {
        for_each = load_balancer_info.value.target_group_pair != null ? [load_balancer_info.value.target_group_pair] : []

        content {
          dynamic "target_group" {
            for_each = target_group_pair_info.value.target_group_names

            content {
              name = target_group.value
            }
          }

          prod_traffic_route {
            listener_arns = target_group_pair_info.value.prod_listener_arns
          }

          dynamic "test_traffic_route" {
            for_each = length(target_group_pair_info.value.test_listener_arns) > 0 ? [1] : []

            content {
              listener_arns = target_group_pair_info.value.test_listener_arns
            }
          }
        }
      }
    }
  }

  dynamic "auto_rollback_configuration" {
    for_each = each.value.auto_rollback != null ? [each.value.auto_rollback] : []

    content {
      enabled = auto_rollback_configuration.value.enabled
      events  = auto_rollback_configuration.value.events
    }
  }

  dynamic "alarm_configuration" {
    for_each = each.value.alarm_configuration != null ? [each.value.alarm_configuration] : []

    content {
      alarms                    = alarm_configuration.value.alarms
      enabled                   = alarm_configuration.value.enabled
      ignore_poll_alarm_failure = alarm_configuration.value.ignore_poll_alarm_failure
    }
  }

  dynamic "trigger_configuration" {
    for_each = each.value.triggers

    content {
      trigger_name       = trigger_configuration.value.name
      trigger_events     = trigger_configuration.value.events
      trigger_target_arn = trigger_configuration.value.target_arn
    }
  }

  dynamic "ec2_tag_filter" {
    for_each = each.value.ec2_tag_filters

    content {
      key   = ec2_tag_filter.value.key
      type  = ec2_tag_filter.value.type
      value = ec2_tag_filter.value.value
    }
  }

  dynamic "ec2_tag_set" {
    for_each = each.value.ec2_tag_sets

    content {
      dynamic "ec2_tag_filter" {
        for_each = ec2_tag_set.value

        content {
          key   = ec2_tag_filter.value.key
          type  = ec2_tag_filter.value.type
          value = ec2_tag_filter.value.value
        }
      }
    }
  }

  dynamic "on_premises_instance_tag_filter" {
    for_each = each.value.on_premises_instance_tag_filters

    content {
      key   = on_premises_instance_tag_filter.value.key
      type  = on_premises_instance_tag_filter.value.type
      value = on_premises_instance_tag_filter.value.value
    }
  }

  tags = merge(
    var.tags,
    each.value.tags,
    { Name = coalesce(each.value.name, each.key) }
  )

  lifecycle {
    precondition {
      condition     = !local.is_ecs || (each.value.blue_green != null && length(each.value.ecs_services) > 0 && try(each.value.load_balancer_info.target_group_pair, null) != null)
      error_message = "An ECS deployment group needs blue_green, ecs_services and load_balancer_info.target_group_pair."
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.default,
    aws_iam_role_policy_attachment.managed
  ]
}
