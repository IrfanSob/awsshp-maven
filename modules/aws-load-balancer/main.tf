locals {
  is_alb = var.load_balancer_type == "application"
  is_nlb = var.load_balancer_type == "network"

  use_subnet_mapping = length(var.subnet_mapping) > 0

  # Flatten the targets nested under each target group into one map so a single
  # attachment resource covers every target group.
  target_attachments = {
    for item in flatten([
      for tg_key, tg in var.target_groups : [
        for target_key, target in tg.targets : {
          key               = "${tg_key}-${target_key}"
          target_group_key  = tg_key
          target_id         = target.target_id
          port              = target.port
          availability_zone = target.availability_zone
        }
      ]
    ]) : item.key => item
  }

  managed_listeners  = { for k, l in var.listeners : k => l if !l.ignore_default_action_changes }
  external_listeners = { for k, l in var.listeners : k => l if l.ignore_default_action_changes }

  listener_arns = merge(
    { for k, l in aws_lb_listener.this : k => l.arn },
    { for k, l in aws_lb_listener.external_action : k => l.arn }
  )

  # Extra certificates beyond the listener's primary one, flattened for SNI.
  listener_certificates = {
    for item in flatten([
      for listener_key, listener in var.listeners : [
        for certificate_arn in listener.additional_certificate_arns : {
          key             = "${listener_key}-${certificate_arn}"
          listener_key    = listener_key
          certificate_arn = certificate_arn
        }
      ]
    ]) : item.key => item
  }
}

# Load Balancer
resource "aws_lb" "this" {
  name               = var.name
  load_balancer_type = var.load_balancer_type
  internal           = var.internal

  # subnets and subnet_mapping are mutually exclusive
  subnets         = local.use_subnet_mapping ? null : var.subnets
  security_groups = length(var.security_group_ids) > 0 ? var.security_group_ids : null

  dynamic "subnet_mapping" {
    for_each = var.subnet_mapping
    content {
      subnet_id            = subnet_mapping.value.subnet_id
      allocation_id        = subnet_mapping.value.allocation_id
      private_ipv4_address = subnet_mapping.value.private_ipv4_address
      ipv6_address         = subnet_mapping.value.ipv6_address
    }
  }

  ip_address_type            = var.ip_address_type
  enable_deletion_protection = var.enable_deletion_protection

  # Application Load Balancer only
  idle_timeout               = local.is_alb ? var.idle_timeout : null
  enable_http2               = local.is_alb ? var.enable_http2 : null
  drop_invalid_header_fields = local.is_alb ? var.drop_invalid_header_fields : null
  preserve_host_header       = local.is_alb ? var.preserve_host_header : null

  # Network Load Balancer only. An ALB is always cross-zone and rejects this.
  enable_cross_zone_load_balancing = local.is_nlb ? var.enable_cross_zone_load_balancing : null

  dynamic "access_logs" {
    for_each = var.access_logs != null ? [var.access_logs] : []
    content {
      bucket  = access_logs.value.bucket
      prefix  = access_logs.value.prefix
      enabled = access_logs.value.enabled
    }
  }

  tags = merge(
    var.tags,
    { "Name" = var.name }
  )

  lifecycle {
    precondition {
      condition     = !local.is_alb || length(var.security_group_ids) > 0
      error_message = "An Application Load Balancer requires at least one entry in security_group_ids."
    }

    precondition {
      condition     = local.use_subnet_mapping || length(var.subnets) >= 2
      error_message = "A load balancer requires at least two subnets in different availability zones."
    }
  }
}

# Target Groups
resource "aws_lb_target_group" "this" {
  for_each = var.target_groups

  name        = coalesce(each.value.name, "${var.name}-${each.key}")
  target_type = each.value.target_type
  vpc_id      = each.value.target_type == "lambda" ? null : coalesce(each.value.vpc_id, var.vpc_id)

  port             = each.value.target_type == "lambda" ? null : each.value.port
  protocol         = each.value.target_type == "lambda" ? null : each.value.protocol
  protocol_version = local.is_alb ? each.value.protocol_version : null

  deregistration_delay          = each.value.deregistration_delay
  load_balancing_algorithm_type = local.is_alb ? each.value.load_balancing_algorithm_type : null
  slow_start                    = local.is_alb ? each.value.slow_start : null

  # Network Load Balancer only
  preserve_client_ip = local.is_nlb ? each.value.preserve_client_ip : null
  proxy_protocol_v2  = local.is_nlb ? each.value.proxy_protocol_v2 : null

  dynamic "health_check" {
    for_each = each.value.health_check != null ? [each.value.health_check] : []
    content {
      enabled             = health_check.value.enabled
      healthy_threshold   = health_check.value.healthy_threshold
      unhealthy_threshold = health_check.value.unhealthy_threshold
      interval            = health_check.value.interval
      timeout             = health_check.value.timeout
      path                = health_check.value.path
      port                = health_check.value.port
      protocol            = health_check.value.protocol
      matcher             = health_check.value.matcher
    }
  }

  dynamic "stickiness" {
    for_each = each.value.stickiness != null ? [each.value.stickiness] : []
    content {
      enabled         = stickiness.value.enabled
      type            = stickiness.value.type
      cookie_duration = stickiness.value.cookie_duration
      cookie_name     = stickiness.value.cookie_name
    }
  }

  tags = merge(
    var.tags,
    each.value.tags,
    { "Name" = coalesce(each.value.name, "${var.name}-${each.key}") }
  )

  lifecycle {
    create_before_destroy = true

    precondition {
      condition = (
        each.value.target_type == "lambda" ||
        coalesce(each.value.vpc_id, var.vpc_id, "") != ""
      )
      error_message = "vpc_id must be set either on the module or on the target group for instance, ip and alb target types."
    }
  }
}

# Target Group Attachments
resource "aws_lb_target_group_attachment" "this" {
  for_each = local.target_attachments

  target_group_arn  = aws_lb_target_group.this[each.value.target_group_key].arn
  target_id         = each.value.target_id
  port              = each.value.port
  availability_zone = each.value.availability_zone
}

# Listeners
resource "aws_lb_listener" "this" {
  for_each = local.managed_listeners

  load_balancer_arn = aws_lb.this.arn
  port              = each.value.port
  protocol          = each.value.protocol
  certificate_arn   = each.value.certificate_arn
  ssl_policy        = each.value.certificate_arn != null ? each.value.ssl_policy : null
  alpn_policy       = local.is_nlb ? each.value.alpn_policy : null

  dynamic "default_action" {
    for_each = each.value.action_type == "forward" ? [1] : []
    content {
      type = "forward"
      target_group_arn = (
        each.value.target_group_arn != null
        ? each.value.target_group_arn
        : aws_lb_target_group.this[each.value.target_group_key].arn
      )
    }
  }

  dynamic "default_action" {
    for_each = each.value.action_type == "redirect" ? [each.value.redirect] : []
    content {
      type = "redirect"

      redirect {
        host        = default_action.value.host
        path        = default_action.value.path
        port        = default_action.value.port
        protocol    = default_action.value.protocol
        query       = default_action.value.query
        status_code = default_action.value.status_code
      }
    }
  }

  dynamic "default_action" {
    for_each = each.value.action_type == "fixed-response" ? [each.value.fixed_response] : []
    content {
      type = "fixed-response"

      fixed_response {
        content_type = default_action.value.content_type
        message_body = default_action.value.message_body
        status_code  = default_action.value.status_code
      }
    }
  }

  tags = merge(
    var.tags,
    each.value.tags,
    { "Name" = "${var.name}-${each.key}" }
  )

  lifecycle {
    precondition {
      condition = (
        each.value.action_type != "forward" ||
        each.value.target_group_arn != null ||
        contains(keys(var.target_groups), coalesce(each.value.target_group_key, "__unset__"))
      )
      error_message = "A forward listener needs target_group_key naming an entry in target_groups, or an explicit target_group_arn."
    }

    precondition {
      condition     = each.value.action_type != "redirect" || each.value.redirect != null
      error_message = "A redirect listener requires the redirect block."
    }

    precondition {
      condition     = each.value.action_type != "fixed-response" || each.value.fixed_response != null
      error_message = "A fixed-response listener requires the fixed_response block."
    }
  }
}

# Listeners - default action managed outside Terraform (e.g. CodeDeploy blue/green)
resource "aws_lb_listener" "external_action" {
  for_each = local.external_listeners

  load_balancer_arn = aws_lb.this.arn
  port              = each.value.port
  protocol          = each.value.protocol
  certificate_arn   = each.value.certificate_arn
  ssl_policy        = each.value.certificate_arn != null ? each.value.ssl_policy : null
  alpn_policy       = local.is_nlb ? each.value.alpn_policy : null

  default_action {
    type = "forward"
    target_group_arn = (
      each.value.target_group_arn != null
      ? each.value.target_group_arn
      : aws_lb_target_group.this[each.value.target_group_key].arn
    )
  }

  tags = merge(
    var.tags,
    each.value.tags,
    { "Name" = "${var.name}-${each.key}" }
  )

  lifecycle {
    ignore_changes = [default_action]

    precondition {
      condition     = each.value.action_type == "forward"
      error_message = "ignore_default_action_changes is only supported on forward listeners."
    }

    precondition {
      condition = (
        each.value.target_group_arn != null ||
        contains(keys(var.target_groups), coalesce(each.value.target_group_key, "__unset__"))
      )
      error_message = "A forward listener needs target_group_key naming an entry in target_groups, or an explicit target_group_arn."
    }
  }
}

# Additional listener certificates for SNI
resource "aws_lb_listener_certificate" "this" {
  for_each = local.listener_certificates

  listener_arn    = local.listener_arns[each.value.listener_key]
  certificate_arn = each.value.certificate_arn
}

# Listener Rules - Application Load Balancer only
resource "aws_lb_listener_rule" "this" {
  for_each = local.is_alb ? var.listener_rules : {}

  listener_arn = local.listener_arns[each.value.listener_key]
  priority     = each.value.priority

  dynamic "action" {
    for_each = each.value.action_type == "forward" ? [1] : []
    content {
      type = "forward"
      target_group_arn = (
        each.value.target_group_arn != null
        ? each.value.target_group_arn
        : aws_lb_target_group.this[each.value.target_group_key].arn
      )
    }
  }

  dynamic "action" {
    for_each = each.value.action_type == "redirect" ? [each.value.redirect] : []
    content {
      type = "redirect"

      redirect {
        host        = action.value.host
        path        = action.value.path
        port        = action.value.port
        protocol    = action.value.protocol
        query       = action.value.query
        status_code = action.value.status_code
      }
    }
  }

  dynamic "action" {
    for_each = each.value.action_type == "fixed-response" ? [each.value.fixed_response] : []
    content {
      type = "fixed-response"

      fixed_response {
        content_type = action.value.content_type
        message_body = action.value.message_body
        status_code  = action.value.status_code
      }
    }
  }

  dynamic "condition" {
    for_each = each.value.conditions

    content {
      dynamic "path_pattern" {
        for_each = condition.value.path_patterns != null ? [1] : []
        content {
          values = condition.value.path_patterns
        }
      }

      dynamic "host_header" {
        for_each = condition.value.host_headers != null ? [1] : []
        content {
          values = condition.value.host_headers
        }
      }

      dynamic "http_request_method" {
        for_each = condition.value.http_request_methods != null ? [1] : []
        content {
          values = condition.value.http_request_methods
        }
      }

      dynamic "source_ip" {
        for_each = condition.value.source_ips != null ? [1] : []
        content {
          values = condition.value.source_ips
        }
      }

      dynamic "http_header" {
        for_each = condition.value.http_header != null ? [condition.value.http_header] : []
        content {
          http_header_name = http_header.value.name
          values           = http_header.value.values
        }
      }

      dynamic "query_string" {
        for_each = coalesce(condition.value.query_strings, [])
        content {
          key   = query_string.value.key
          value = query_string.value.value
        }
      }
    }
  }

  tags = merge(
    var.tags,
    each.value.tags,
    { "Name" = "${var.name}-${each.key}" }
  )
}
