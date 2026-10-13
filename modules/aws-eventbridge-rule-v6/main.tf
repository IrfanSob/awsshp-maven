# Reusable EventBridge rule module.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.6.0"
    }
  }
}

locals {
  event_bus_name = var.create_event_bus ? one(aws_cloudwatch_event_bus.this[*].name) : var.event_bus_name

  targets = merge([
    for rk, r in var.rules : {
      for tk, t in r.targets : "${rk}|${tk}" => merge(t, { rule_key = rk, target_key = tk })
    }
  ]...)
}

# Custom Event Bus (toggle: create_event_bus)
resource "aws_cloudwatch_event_bus" "this" {
  count = var.create_event_bus ? 1 : 0

  name               = var.event_bus_name
  description        = var.event_bus_description
  event_source_name  = var.event_bus_event_source_name
  kms_key_identifier = var.event_bus_kms_key_identifier

  dynamic "dead_letter_config" {
    for_each = var.event_bus_dead_letter_arn != null ? [1] : []

    content {
      arn = var.event_bus_dead_letter_arn
    }
  }

  dynamic "log_config" {
    for_each = var.event_bus_log_config != null ? [var.event_bus_log_config] : []

    content {
      include_detail = log_config.value.include_detail
      level          = log_config.value.level
    }
  }

  tags = merge(
    var.tags,
    { Name = var.event_bus_name }
  )
}

# Rules
resource "aws_cloudwatch_event_rule" "this" {
  for_each = var.rules

  name                = each.value.name_prefix == null ? coalesce(each.value.name, each.key) : null
  name_prefix         = each.value.name_prefix
  description         = each.value.description
  event_bus_name      = local.event_bus_name
  event_pattern       = each.value.event_pattern
  schedule_expression = each.value.schedule_expression
  state               = each.value.state
  role_arn            = each.value.role_arn
  force_destroy       = each.value.force_destroy

  tags = merge(
    var.tags,
    each.value.tags,
    { Name = coalesce(each.value.name, each.value.name_prefix, each.key) }
  )

  lifecycle {
    precondition {
      condition     = each.value.event_pattern != null || each.value.schedule_expression != null
      error_message = "Each rule needs event_pattern or schedule_expression."
    }
  }
}

# Targets
resource "aws_cloudwatch_event_target" "this" {
  for_each = local.targets

  rule           = aws_cloudwatch_event_rule.this[each.value.rule_key].name
  event_bus_name = local.event_bus_name
  target_id      = coalesce(each.value.target_id, each.value.target_key)
  arn            = each.value.arn
  role_arn       = each.value.role_arn
  input          = each.value.input
  input_path     = each.value.input_path
  force_destroy  = each.value.force_destroy

  dynamic "input_transformer" {
    for_each = each.value.input_transformer != null ? [each.value.input_transformer] : []

    content {
      input_paths    = input_transformer.value.input_paths
      input_template = input_transformer.value.input_template
    }
  }

  dynamic "retry_policy" {
    for_each = each.value.retry_policy != null ? [each.value.retry_policy] : []

    content {
      maximum_event_age_in_seconds = retry_policy.value.maximum_event_age_in_seconds
      maximum_retry_attempts       = retry_policy.value.maximum_retry_attempts
    }
  }

  dynamic "dead_letter_config" {
    for_each = each.value.dead_letter_arn != null ? [1] : []

    content {
      arn = each.value.dead_letter_arn
    }
  }

  dynamic "sqs_target" {
    for_each = each.value.sqs_message_group_id != null ? [1] : []

    content {
      message_group_id = each.value.sqs_message_group_id
    }
  }

  dynamic "kinesis_target" {
    for_each = each.value.kinesis_partition_key_path != null ? [1] : []

    content {
      partition_key_path = each.value.kinesis_partition_key_path
    }
  }

  dynamic "http_target" {
    for_each = each.value.http_target != null ? [each.value.http_target] : []

    content {
      header_parameters       = http_target.value.header_parameters
      path_parameter_values   = http_target.value.path_parameter_values
      query_string_parameters = http_target.value.query_string_parameters
    }
  }

  dynamic "run_command_targets" {
    for_each = each.value.run_command_targets

    content {
      key    = run_command_targets.value.key
      values = run_command_targets.value.values
    }
  }

  dynamic "ecs_target" {
    for_each = each.value.ecs_target != null ? [each.value.ecs_target] : []

    content {
      task_definition_arn     = ecs_target.value.task_definition_arn
      task_count              = ecs_target.value.task_count
      launch_type             = ecs_target.value.launch_type
      platform_version        = ecs_target.value.platform_version
      group                   = ecs_target.value.group
      enable_ecs_managed_tags = ecs_target.value.enable_ecs_managed_tags
      enable_execute_command  = ecs_target.value.enable_execute_command
      propagate_tags          = ecs_target.value.propagate_tags
      tags                    = ecs_target.value.tags

      dynamic "network_configuration" {
        for_each = ecs_target.value.network_configuration != null ? [ecs_target.value.network_configuration] : []

        content {
          subnets          = network_configuration.value.subnets
          security_groups  = network_configuration.value.security_groups
          assign_public_ip = network_configuration.value.assign_public_ip
        }
      }

      dynamic "capacity_provider_strategy" {
        for_each = ecs_target.value.capacity_provider_strategy

        content {
          capacity_provider = capacity_provider_strategy.value.capacity_provider
          weight            = capacity_provider_strategy.value.weight
          base              = capacity_provider_strategy.value.base
        }
      }

      dynamic "ordered_placement_strategy" {
        for_each = ecs_target.value.ordered_placement_strategy

        content {
          type  = ordered_placement_strategy.value.type
          field = ordered_placement_strategy.value.field
        }
      }

      dynamic "placement_constraint" {
        for_each = ecs_target.value.placement_constraint

        content {
          type       = placement_constraint.value.type
          expression = placement_constraint.value.expression
        }
      }
    }
  }

  dynamic "batch_target" {
    for_each = each.value.batch_target != null ? [each.value.batch_target] : []

    content {
      job_definition = batch_target.value.job_definition
      job_name       = batch_target.value.job_name
      array_size     = batch_target.value.array_size
      job_attempts   = batch_target.value.job_attempts
    }
  }

  dynamic "redshift_target" {
    for_each = each.value.redshift_target != null ? [each.value.redshift_target] : []

    content {
      database            = redshift_target.value.database
      db_user             = redshift_target.value.db_user
      secrets_manager_arn = redshift_target.value.secrets_manager_arn
      sql                 = redshift_target.value.sql
      statement_name      = redshift_target.value.statement_name
      with_event          = redshift_target.value.with_event
    }
  }

  dynamic "sagemaker_pipeline_target" {
    for_each = length(each.value.sagemaker_pipeline_parameters) > 0 ? [1] : []

    content {
      dynamic "pipeline_parameter_list" {
        for_each = each.value.sagemaker_pipeline_parameters

        content {
          name  = pipeline_parameter_list.key
          value = pipeline_parameter_list.value
        }
      }
    }
  }

  dynamic "appsync_target" {
    for_each = each.value.appsync_graphql_operation != null ? [1] : []

    content {
      graphql_operation = each.value.appsync_graphql_operation
    }
  }
}
