variable "name" {
  description = "WAF Web ACL name"
  type        = string
}

variable "description" {
  description = "WAF Web ACL description"
  type        = string
  default     = "Managed by Terraform"
}

variable "scope" {
  description = "WAF scope. Use REGIONAL for ALB/API Gateway/AppSync/Cognito, CLOUDFRONT for CloudFront."
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "scope must be REGIONAL or CLOUDFRONT."
  }
}

variable "default_action" {
  description = "Default action for requests that do not match any rule. Valid values: allow, block."
  type        = string
  default     = "allow"

  validation {
    condition     = contains(["allow", "block"], lower(var.default_action))
    error_message = "default_action must be allow or block."
  }
}

variable "metric_name" {
  description = "Metric name for Web ACL visibility config"
  type        = string
  default     = null
  nullable    = true
}

variable "cloudwatch_metrics_enabled" {
  description = "Enable CloudWatch metrics for WAF"
  type        = bool
  default     = true
}

variable "sampled_requests_enabled" {
  description = "Enable sampled requests for WAF"
  type        = bool
  default     = true
}

variable "aws_managed_rule_groups" {
  description = "AWS managed rule groups to attach to Web ACL"
  type = map(object({
    name                    = string
    priority                = number
    vendor_name             = optional(string, "AWS")
    managed_rule_group_name = string
    version                 = optional(string)
    override_action         = optional(string, "none")

    rule_action_overrides = optional(list(object({
      name          = string
      action_to_use = string
    })), [])

    metric_name                = optional(string)
    cloudwatch_metrics_enabled = optional(bool)
    sampled_requests_enabled   = optional(bool)
  }))
  default = {}

  validation {
    condition = alltrue([
      for _, group in var.aws_managed_rule_groups :
      contains(["none", "count"], lower(group.override_action))
    ])
    error_message = "override_action for managed rule group must be none or count."
  }
}

variable "rate_based_rules" {
  description = "Optional rate-based rules"
  type = map(object({
    name               = string
    priority           = number
    action             = string
    limit              = number
    aggregate_key_type = optional(string, "IP")

    metric_name                = optional(string)
    cloudwatch_metrics_enabled = optional(bool)
    sampled_requests_enabled   = optional(bool)
  }))
  default = {}

  validation {
    condition = alltrue([
      for _, rule in var.rate_based_rules :
      contains(["allow", "block", "count", "captcha", "challenge"], lower(rule.action))
    ])
    error_message = "rate_based_rules action must be allow, block, count, captcha, or challenge."
  }
}

variable "create_web_acl_association" {
  description = "Whether Terraform should associate WAF Web ACL to a resource ARN. For ALB created by AWS Load Balancer Controller, recommended false and use Ingress annotation instead."
  type        = bool
  default     = false
}

variable "association_resource_arn" {
  description = "Resource ARN to associate WAF Web ACL with, such as ALB ARN. Required if create_web_acl_association is true."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_logging" {
  description = "Enable WAF logging"
  type        = bool
  default     = false
}

variable "create_log_group" {
  description = "Create CloudWatch log group for WAF logs"
  type        = bool
  default     = true
}

variable "log_group_name" {
  description = "CloudWatch Log Group name for WAF logs. AWS WAF log group name should start with aws-waf-logs-."
  type        = string
  default     = null
  nullable    = true
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "log_group_kms_key_id" {
  description = "KMS key ARN for CloudWatch Log Group encryption"
  type        = string
  default     = null
  nullable    = true
}

variable "existing_log_destination_arn" {
  description = "Existing log destination ARN if create_log_group is false"
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.create_log_group == true ||
      var.existing_log_destination_arn != null
    )
    error_message = "existing_log_destination_arn must be provided when create_log_group is false."
  }
}

variable "redacted_single_header_fields" {
  description = "Single header names to redact from WAF logs, such as authorization or cookie"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}