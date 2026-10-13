# --- Load balancer -------------------------------------------------------------

variable "name" {
  description = "Name of the load balancer, also used as the prefix for generated target group and listener names"
  type        = string
}

variable "load_balancer_type" {
  description = "Type of load balancer to create"
  type        = string
  default     = "application"

  validation {
    condition     = contains(["application", "network"], var.load_balancer_type)
    error_message = "load_balancer_type must be either application or network."
  }
}

variable "internal" {
  description = "Whether the load balancer is internal. False places it in public subnets with an internet facing scheme"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID used by target groups. May be overridden per target group"
  type        = string
  default     = null
}

variable "subnets" {
  description = "Subnet IDs the load balancer spans. At least two, in different availability zones. Ignored when subnet_mapping is set"
  type        = list(string)
  default     = []
}

variable "subnet_mapping" {
  description = "Per subnet configuration, used mainly on a Network Load Balancer to pin static or Elastic IPs. Mutually exclusive with subnets"
  type = list(object({
    subnet_id            = string
    allocation_id        = optional(string)
    private_ipv4_address = optional(string)
    ipv6_address         = optional(string)
  }))
  default = []
}

variable "security_group_ids" {
  description = "Security group IDs to attach. Required for an Application Load Balancer, optional for a Network Load Balancer"
  type        = list(string)
  default     = []
}

variable "ip_address_type" {
  description = "Address family for the load balancer, for example ipv4 or dualstack"
  type        = string
  default     = null
}

variable "enable_deletion_protection" {
  description = "Prevent the load balancer from being destroyed"
  type        = bool
  default     = false
}

variable "enable_cross_zone_load_balancing" {
  description = "Distribute traffic across availability zones. Network Load Balancer only, an Application Load Balancer is always cross zone"
  type        = bool
  default     = null
}

variable "idle_timeout" {
  description = "Idle connection timeout in seconds. Application Load Balancer only"
  type        = number
  default     = null
}

variable "enable_http2" {
  description = "Enable HTTP/2. Application Load Balancer only"
  type        = bool
  default     = null
}

variable "drop_invalid_header_fields" {
  description = "Drop HTTP headers with invalid names. Application Load Balancer only"
  type        = bool
  default     = null
}

variable "preserve_host_header" {
  description = "Preserve the Host header sent by the client. Application Load Balancer only"
  type        = bool
  default     = null
}

variable "access_logs" {
  description = "S3 access log configuration for the load balancer"
  type = object({
    bucket  = string
    prefix  = optional(string)
    enabled = optional(bool, true)
  })
  default = null
}

# --- Target groups ---------------------------------------------------------------

variable "target_groups" {
  description = "Target groups to create, keyed by a short name that listeners and rules refer to"
  type = map(object({
    name             = optional(string)
    port             = optional(number)
    protocol         = optional(string)
    protocol_version = optional(string)
    target_type      = optional(string, "instance")
    vpc_id           = optional(string)

    deregistration_delay          = optional(number)
    load_balancing_algorithm_type = optional(string)
    slow_start                    = optional(number)

    # Network Load Balancer only
    preserve_client_ip = optional(string)
    proxy_protocol_v2  = optional(bool)

    health_check = optional(object({
      enabled             = optional(bool, true)
      healthy_threshold   = optional(number)
      unhealthy_threshold = optional(number)
      interval            = optional(number)
      timeout             = optional(number)
      path                = optional(string)
      port                = optional(string)
      protocol            = optional(string)
      matcher             = optional(string)
    }))

    stickiness = optional(object({
      type            = string
      enabled         = optional(bool, true)
      cookie_duration = optional(number)
      cookie_name     = optional(string)
    }))

    # Targets registered by Terraform. Leave empty when an orchestrator registers them
    targets = optional(map(object({
      target_id         = string
      port              = optional(number)
      availability_zone = optional(string)
    })), {})

    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, tg in var.target_groups :
      contains(["instance", "ip", "lambda", "alb"], tg.target_type)
    ])
    error_message = "target_type must be one of: instance, ip, lambda, alb."
  }
}

# --- Listeners -------------------------------------------------------------------

variable "listeners" {
  description = "Listeners to create, keyed by a short name. Set ignore_default_action_changes on a forward listener whose target group is swapped by an external controller such as CodeDeploy blue/green, so Terraform stops reverting it. Changing that flag on an existing listener replaces the listener"
  type = map(object({
    port     = number
    protocol = string

    ignore_default_action_changes = optional(bool, false)

    certificate_arn             = optional(string)
    additional_certificate_arns = optional(list(string), [])
    ssl_policy                  = optional(string, "ELBSecurityPolicy-TLS13-1-2-2021-06")
    alpn_policy                 = optional(string)

    # Default action. forward needs target_group_key or target_group_arn
    action_type      = optional(string, "forward")
    target_group_key = optional(string)
    target_group_arn = optional(string)

    redirect = optional(object({
      status_code = string
      host        = optional(string)
      path        = optional(string)
      port        = optional(string)
      protocol    = optional(string)
      query       = optional(string)
    }))

    fixed_response = optional(object({
      content_type = string
      message_body = optional(string)
      status_code  = optional(string)
    }))

    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, l in var.listeners :
      contains(["forward", "redirect", "fixed-response"], l.action_type)
    ])
    error_message = "listener action_type must be one of: forward, redirect, fixed-response."
  }
}

# --- Listener rules ---------------------------------------------------------------

variable "listener_rules" {
  description = "Listener rules for host and path routing. Application Load Balancer only, ignored for a Network Load Balancer"
  type = map(object({
    listener_key = string
    priority     = number

    action_type      = optional(string, "forward")
    target_group_key = optional(string)
    target_group_arn = optional(string)

    redirect = optional(object({
      status_code = string
      host        = optional(string)
      path        = optional(string)
      port        = optional(string)
      protocol    = optional(string)
      query       = optional(string)
    }))

    fixed_response = optional(object({
      content_type = string
      message_body = optional(string)
      status_code  = optional(string)
    }))

    conditions = list(object({
      path_patterns        = optional(list(string))
      host_headers         = optional(list(string))
      http_request_methods = optional(list(string))
      source_ips           = optional(list(string))

      http_header = optional(object({
        name   = string
        values = list(string)
      }))

      query_strings = optional(list(object({
        key   = optional(string)
        value = string
      })))
    }))

    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, r in var.listener_rules :
      length(r.conditions) > 0
    ])
    error_message = "Each listener rule requires at least one condition."
  }
}

# --- Tags -------------------------------------------------------------------------

variable "tags" {
  description = "A map of tags to apply to all resources created by this module"
  type        = map(string)
  default     = {}
}
