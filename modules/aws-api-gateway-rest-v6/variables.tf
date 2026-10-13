# --- General -------------------------------------------------------------------

variable "create_rest_api" {
  description = "Whether to create the REST API and every resource in this module"
  type        = bool
  default     = true
}

variable "name" {
  description = "REST API name, also the base for generated resource names"
  type        = string
}

variable "description" {
  description = "REST API description"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to every taggable resource in this module"
  type        = map(string)
  default     = {}
}

# --- REST API ------------------------------------------------------------------

variable "endpoint_type" {
  description = "REGIONAL, EDGE or PRIVATE"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "EDGE", "PRIVATE"], var.endpoint_type)
    error_message = "endpoint_type must be REGIONAL, EDGE or PRIVATE."
  }
}

variable "vpc_endpoint_ids" {
  description = "execute-api VPC endpoint IDs for a PRIVATE API"
  type        = list(string)
  default     = null
}

variable "ip_address_type" {
  description = "ipv4 or dualstack. Null keeps the AWS default"
  type        = string
  default     = null
}

variable "api_key_source" {
  description = "HEADER or AUTHORIZER"
  type        = string
  default     = null
}

variable "binary_media_types" {
  description = "Binary media types supported by the API"
  type        = list(string)
  default     = null
}

variable "minimum_compression_size" {
  description = "Minimum response size in bytes to compress (-1 to 10485760), as a string. Null disables compression"
  type        = string
  default     = null
}

variable "disable_execute_api_endpoint" {
  description = "Disable the default execute-api endpoint (use with a custom domain)"
  type        = bool
  default     = null
}

variable "security_policy" {
  description = "TLS security policy of the default endpoint, e.g. TLS_1_2 or SecurityPolicy_TLS13_1_2_2021_06"
  type        = string
  default     = null
}

variable "endpoint_access_mode" {
  description = "BASIC or STRICT, only for SecurityPolicy_ security policies"
  type        = string
  default     = null
}

variable "policy_json" {
  description = "Resource policy JSON for the API. Null creates no policy"
  type        = string
  default     = null
}

variable "openapi_body" {
  description = "OpenAPI definition. When set it defines the API instead of (or merged with, see put_rest_api_mode) the methods variable"
  type        = string
  default     = null
}

variable "put_rest_api_mode" {
  description = "merge or overwrite, used with openapi_body"
  type        = string
  default     = "overwrite"
}

variable "openapi_import_parameters" {
  description = "Import customizations for openapi_body, e.g. { ignore = \"documentation\" }"
  type        = map(string)
  default     = null
}

variable "fail_on_warnings" {
  description = "Fail on warnings while creating or updating the API"
  type        = bool
  default     = null
}

# --- VPC links -----------------------------------------------------------------

variable "create_vpc_link_v2" {
  description = "Create a VPC Link v2 for private integrations with an ALB or NLB (integration.vpc_link = \"v2\")"
  type        = bool
  default     = false
}

variable "vpc_link_v2_name" {
  description = "VPC Link v2 name. Defaults to <name>-vpc-link"
  type        = string
  default     = null
}

variable "vpc_link_v2_subnet_ids" {
  description = "Subnets for the VPC Link v2 network interfaces"
  type        = list(string)
  default     = []
}

variable "vpc_link_v2_security_group_ids" {
  description = "Security groups for the VPC Link v2 network interfaces. The ALB security group must allow them"
  type        = list(string)
  default     = []
}

variable "create_vpc_link_v1" {
  description = "Create a VPC Link v1, NLB targets only (integration.vpc_link = \"v1\")"
  type        = bool
  default     = false
}

variable "vpc_link_v1_name" {
  description = "VPC Link v1 name. Defaults to <name>-vpc-link-v1"
  type        = string
  default     = null
}

variable "vpc_link_v1_description" {
  description = "VPC Link v1 description"
  type        = string
  default     = null
}

variable "vpc_link_v1_target_arns" {
  description = "NLB ARN for the VPC Link v1 (one target)"
  type        = list(string)
  default     = []
}

# --- Methods -------------------------------------------------------------------

variable "methods" {
  description = "Methods keyed by a short name. path is the full resource path (\"/\", \"/claims\", \"/{proxy+}\", max 6 levels); parent resources are created automatically. integration.vpc_link (v1 or v2) routes through the VPC link created here, with integration_target set to the load balancer ARN for v2. method_responses and integration_responses are keyed by status code"
  type = map(object({
    path                  = string
    http_method           = string
    authorization         = optional(string, "NONE")
    authorizer_key        = optional(string)
    authorizer_id         = optional(string)
    authorization_scopes  = optional(list(string))
    api_key_required      = optional(bool, false)
    operation_name        = optional(string)
    request_models        = optional(map(string))
    request_parameters    = optional(map(bool))
    request_validator_key = optional(string)

    integration = object({
      type                       = string
      integration_http_method    = optional(string)
      uri                        = optional(string)
      vpc_link                   = optional(string)
      connection_type            = optional(string)
      connection_id              = optional(string)
      integration_target         = optional(string)
      credentials                = optional(string)
      request_parameters         = optional(map(string))
      request_templates          = optional(map(string))
      passthrough_behavior       = optional(string)
      cache_key_parameters       = optional(list(string))
      cache_namespace            = optional(string)
      content_handling           = optional(string)
      timeout_milliseconds       = optional(number)
      response_transfer_mode     = optional(string)
      insecure_skip_verification = optional(bool)
    })

    method_responses = optional(map(object({
      response_models     = optional(map(string))
      response_parameters = optional(map(bool))
    })), {})

    integration_responses = optional(map(object({
      selection_pattern   = optional(string)
      response_parameters = optional(map(string))
      response_templates  = optional(map(string))
      content_handling    = optional(string)
    })), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, m in var.methods : m.path == "/" || (startswith(m.path, "/") && !endswith(m.path, "/") && length(split("/", trimprefix(m.path, "/"))) <= 6)
    ])
    error_message = "Each method path must start with /, must not end with / (except the root \"/\") and may have at most 6 segments."
  }

  validation {
    condition = alltrue([
      for k, m in var.methods : m.integration.vpc_link == null || contains(["v1", "v2"], coalesce(m.integration.vpc_link, "v2"))
    ])
    error_message = "integration.vpc_link must be v1 or v2."
  }
}

variable "authorizers" {
  description = "Authorizers keyed by a short name. type is COGNITO_USER_POOLS (with provider_arns), TOKEN or REQUEST (with authorizer_uri)"
  type = map(object({
    name                             = optional(string)
    type                             = optional(string, "COGNITO_USER_POOLS")
    provider_arns                    = optional(list(string))
    authorizer_uri                   = optional(string)
    authorizer_credentials           = optional(string)
    identity_source                  = optional(string)
    identity_validation_expression   = optional(string)
    authorizer_result_ttl_in_seconds = optional(number)
  }))
  default = {}
}

variable "request_validators" {
  description = "Request validators keyed by a short name"
  type = map(object({
    name                        = optional(string)
    validate_request_body       = optional(bool, false)
    validate_request_parameters = optional(bool, false)
  }))
  default = {}
}

variable "models" {
  description = "Models keyed by a short name"
  type = map(object({
    name         = optional(string)
    content_type = string
    description  = optional(string)
    schema       = optional(string)
  }))
  default = {}
}

variable "gateway_responses" {
  description = "Gateway responses keyed by response type, e.g. DEFAULT_4XX, UNAUTHORIZED"
  type = map(object({
    status_code         = optional(string)
    response_parameters = optional(map(string))
    response_templates  = optional(map(string))
  }))
  default = {}
}

# --- Deployment and stages -----------------------------------------------------

variable "create_deployment" {
  description = "Create a deployment and the stages. Set false when deployments are made outside Terraform"
  type        = bool
  default     = true
}

variable "deployment_description" {
  description = "Deployment description"
  type        = string
  default     = null
}

variable "redeployment_triggers" {
  description = "Extra values that force a new deployment when changed"
  type        = map(string)
  default     = {}
}

variable "stages" {
  description = "Stages keyed by a short name. method_settings is keyed by method path (\"*/*\" for all methods, or \"<resource path>/<METHOD>\")"
  type = map(object({
    stage_name            = optional(string)
    description           = optional(string)
    variables             = optional(map(string))
    xray_tracing_enabled  = optional(bool, false)
    cache_cluster_enabled = optional(bool, false)
    cache_cluster_size    = optional(string)
    client_certificate_id = optional(string)
    documentation_version = optional(string)

    access_log = optional(object({
      create_log_group  = optional(bool, true)
      log_group_name    = optional(string)
      retention_in_days = optional(number, 30)
      kms_key_id        = optional(string)
      destination_arn   = optional(string)
      format            = string
    }))

    create_execution_log_group      = optional(bool, false)
    execution_log_retention_in_days = optional(number, 30)
    execution_log_kms_key_id        = optional(string)

    canary_settings = optional(object({
      deployment_id            = string
      percent_traffic          = optional(number)
      stage_variable_overrides = optional(map(string))
      use_stage_cache          = optional(bool)
    }))

    method_settings = optional(map(object({
      metrics_enabled                            = optional(bool)
      logging_level                              = optional(string)
      data_trace_enabled                         = optional(bool)
      throttling_burst_limit                     = optional(number)
      throttling_rate_limit                      = optional(number)
      caching_enabled                            = optional(bool)
      cache_ttl_in_seconds                       = optional(number)
      cache_data_encrypted                       = optional(bool)
      require_authorization_for_cache_control    = optional(bool)
      unauthorized_cache_control_header_strategy = optional(string)
    })), {})

    tags = optional(map(string), {})
  }))
  default = {}
}

variable "create_cloudwatch_role" {
  description = "Create the API Gateway CloudWatch Logs role and set it on the account. This is a per-Region account setting shared by every API"
  type        = bool
  default     = false
}

variable "cloudwatch_role_name" {
  description = "Name of the CloudWatch Logs role. Defaults to <name>-apigw-cloudwatch-role"
  type        = string
  default     = null
}

# --- API keys and usage plans --------------------------------------------------

variable "api_keys" {
  description = "API keys keyed by a short name. Values are generated by AWS unless set in api_key_values"
  type = map(object({
    name        = optional(string)
    description = optional(string)
    enabled     = optional(bool, true)
    customer_id = optional(string)
    tags        = optional(map(string), {})
  }))
  default = {}
}

variable "api_key_values" {
  description = "Optional explicit API key values keyed like api_keys (20-128 alphanumeric characters)"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "usage_plans" {
  description = "Usage plans keyed by a short name. stages refer to stages keys, api_key_keys to api_keys keys"
  type = map(object({
    name         = optional(string)
    description  = optional(string)
    product_code = optional(string)

    stages = optional(list(object({
      stage_key = string
      method_throttles = optional(list(object({
        path        = string
        burst_limit = optional(number)
        rate_limit  = optional(number)
      })), [])
    })), [])

    quota_settings = optional(object({
      limit  = number
      period = string
      offset = optional(number)
    }))

    throttle_settings = optional(object({
      burst_limit = optional(number)
      rate_limit  = optional(number)
    }))

    api_key_keys = optional(list(string), [])
    tags         = optional(map(string), {})
  }))
  default = {}
}

# --- Custom domain -------------------------------------------------------------

variable "custom_domain" {
  description = "Custom domain with base path mappings keyed by a short name. certificate_arn is a Regional ACM certificate for REGIONAL, or a us-east-1 certificate for EDGE"
  type = object({
    domain_name                            = string
    endpoint_type                          = optional(string, "REGIONAL")
    certificate_arn                        = optional(string)
    certificate_name                       = optional(string)
    regional_certificate_name              = optional(string)
    security_policy                        = optional(string, "TLS_1_2")
    endpoint_access_mode                   = optional(string)
    routing_mode                           = optional(string)
    ip_address_type                        = optional(string)
    ownership_verification_certificate_arn = optional(string)
    policy                                 = optional(string)
    truststore_uri                         = optional(string)
    truststore_version                     = optional(string)
    base_path_mappings = optional(map(object({
      stage_key = string
      base_path = optional(string)
    })), {})
  })
  default = null
}
