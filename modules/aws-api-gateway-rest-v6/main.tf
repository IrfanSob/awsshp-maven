# Reusable API Gateway REST API module.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.53.0"
    }
  }
}

data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  rest_api_id      = one(aws_api_gateway_rest_api.this[*].id)
  root_resource_id = one(aws_api_gateway_rest_api.this[*].root_resource_id)

  # Every resource path needed by the methods, including parents, grouped by depth.
  method_paths = distinct([for k, m in var.methods : m.path if m.path != "/"])
  all_paths = distinct(flatten([
    for p in local.method_paths : [
      for i in range(1, length(split("/", trimprefix(p, "/"))) + 1) :
      "/${join("/", slice(split("/", trimprefix(p, "/")), 0, i))}"
    ]
  ]))
  paths_by_depth = {
    for d in range(1, 7) : d => toset([for p in local.all_paths : p if length(split("/", trimprefix(p, "/"))) == d])
  }

  resource_ids = merge(
    { "/" = local.root_resource_id },
    { for k, v in aws_api_gateway_resource.depth1 : k => v.id },
    { for k, v in aws_api_gateway_resource.depth2 : k => v.id },
    { for k, v in aws_api_gateway_resource.depth3 : k => v.id },
    { for k, v in aws_api_gateway_resource.depth4 : k => v.id },
    { for k, v in aws_api_gateway_resource.depth5 : k => v.id },
    { for k, v in aws_api_gateway_resource.depth6 : k => v.id }
  )

  vpc_link_ids = {
    v1 = one(aws_api_gateway_vpc_link.this[*].id)
    v2 = one(aws_apigatewayv2_vpc_link.this[*].id)
  }

  method_responses = merge([
    for mk, m in var.methods : {
      for code, r in m.method_responses : "${mk}|${code}" => merge(r, { method_key = mk, status_code = code })
    }
  ]...)

  integration_responses = merge([
    for mk, m in var.methods : {
      for code, r in m.integration_responses : "${mk}|${code}" => merge(r, { method_key = mk, status_code = code })
    }
  ]...)

  method_settings = merge([
    for sk, s in var.stages : {
      for path, ms in s.method_settings : "${sk}|${path}" => merge(ms, { stage_key = sk, method_path = path })
    }
  ]...)

  access_log_groups = {
    for sk, s in var.stages : sk => s.access_log
    if s.access_log != null && try(s.access_log.create_log_group, false)
  }

  usage_plan_keys = merge([
    for pk, p in var.usage_plans : {
      for key in p.api_key_keys : "${pk}|${key}" => { plan_key = pk, api_key_key = key }
    }
  ]...)

  redeployment_hash = sha1(jsonencode([
    var.openapi_body,
    var.methods,
    var.authorizers,
    var.request_validators,
    var.models,
    var.gateway_responses,
    var.redeployment_triggers
  ]))
}

# REST API
resource "aws_api_gateway_rest_api" "this" {
  count = var.create_rest_api ? 1 : 0

  name                         = var.name
  description                  = var.description
  api_key_source               = var.api_key_source
  binary_media_types           = var.binary_media_types
  minimum_compression_size     = var.minimum_compression_size
  disable_execute_api_endpoint = var.disable_execute_api_endpoint
  security_policy              = var.security_policy
  endpoint_access_mode         = var.endpoint_access_mode
  body                         = var.openapi_body
  put_rest_api_mode            = var.openapi_body != null ? var.put_rest_api_mode : null
  parameters                   = var.openapi_body != null ? var.openapi_import_parameters : null
  fail_on_warnings             = var.fail_on_warnings

  endpoint_configuration {
    types            = [var.endpoint_type]
    vpc_endpoint_ids = var.endpoint_type == "PRIVATE" ? var.vpc_endpoint_ids : null
    ip_address_type  = var.ip_address_type
  }

  tags = merge(
    var.tags,
    { Name = var.name }
  )
}

# REST API Resource Policy (toggle: policy_json)
resource "aws_api_gateway_rest_api_policy" "this" {
  count = var.create_rest_api && var.policy_json != null ? 1 : 0

  rest_api_id = local.rest_api_id
  policy      = var.policy_json
}

# VPC Link v2 - ALB or NLB private integration (toggle: create_vpc_link_v2)
resource "aws_apigatewayv2_vpc_link" "this" {
  count = var.create_rest_api && var.create_vpc_link_v2 ? 1 : 0

  name               = coalesce(var.vpc_link_v2_name, "${var.name}-vpc-link")
  subnet_ids         = var.vpc_link_v2_subnet_ids
  security_group_ids = var.vpc_link_v2_security_group_ids

  tags = merge(
    var.tags,
    { Name = coalesce(var.vpc_link_v2_name, "${var.name}-vpc-link") }
  )
}

# VPC Link v1 - NLB only (toggle: create_vpc_link_v1)
resource "aws_api_gateway_vpc_link" "this" {
  count = var.create_rest_api && var.create_vpc_link_v1 ? 1 : 0

  name        = coalesce(var.vpc_link_v1_name, "${var.name}-vpc-link-v1")
  description = var.vpc_link_v1_description
  target_arns = var.vpc_link_v1_target_arns

  tags = merge(
    var.tags,
    { Name = coalesce(var.vpc_link_v1_name, "${var.name}-vpc-link-v1") }
  )
}

# Resources (path tree, up to 6 levels)
resource "aws_api_gateway_resource" "depth1" {
  for_each = var.create_rest_api ? local.paths_by_depth[1] : toset([])

  rest_api_id = local.rest_api_id
  parent_id   = local.root_resource_id
  path_part   = element(split("/", each.value), length(split("/", each.value)) - 1)
}

resource "aws_api_gateway_resource" "depth2" {
  for_each = var.create_rest_api ? local.paths_by_depth[2] : toset([])

  rest_api_id = local.rest_api_id
  parent_id   = aws_api_gateway_resource.depth1[join("/", slice(split("/", each.value), 0, length(split("/", each.value)) - 1))].id
  path_part   = element(split("/", each.value), length(split("/", each.value)) - 1)
}

resource "aws_api_gateway_resource" "depth3" {
  for_each = var.create_rest_api ? local.paths_by_depth[3] : toset([])

  rest_api_id = local.rest_api_id
  parent_id   = aws_api_gateway_resource.depth2[join("/", slice(split("/", each.value), 0, length(split("/", each.value)) - 1))].id
  path_part   = element(split("/", each.value), length(split("/", each.value)) - 1)
}

resource "aws_api_gateway_resource" "depth4" {
  for_each = var.create_rest_api ? local.paths_by_depth[4] : toset([])

  rest_api_id = local.rest_api_id
  parent_id   = aws_api_gateway_resource.depth3[join("/", slice(split("/", each.value), 0, length(split("/", each.value)) - 1))].id
  path_part   = element(split("/", each.value), length(split("/", each.value)) - 1)
}

resource "aws_api_gateway_resource" "depth5" {
  for_each = var.create_rest_api ? local.paths_by_depth[5] : toset([])

  rest_api_id = local.rest_api_id
  parent_id   = aws_api_gateway_resource.depth4[join("/", slice(split("/", each.value), 0, length(split("/", each.value)) - 1))].id
  path_part   = element(split("/", each.value), length(split("/", each.value)) - 1)
}

resource "aws_api_gateway_resource" "depth6" {
  for_each = var.create_rest_api ? local.paths_by_depth[6] : toset([])

  rest_api_id = local.rest_api_id
  parent_id   = aws_api_gateway_resource.depth5[join("/", slice(split("/", each.value), 0, length(split("/", each.value)) - 1))].id
  path_part   = element(split("/", each.value), length(split("/", each.value)) - 1)
}

# Authorizers
resource "aws_api_gateway_authorizer" "this" {
  for_each = var.create_rest_api ? var.authorizers : {}

  rest_api_id                      = local.rest_api_id
  name                             = coalesce(each.value.name, each.key)
  type                             = each.value.type
  provider_arns                    = each.value.provider_arns
  authorizer_uri                   = each.value.authorizer_uri
  authorizer_credentials           = each.value.authorizer_credentials
  identity_source                  = each.value.identity_source
  identity_validation_expression   = each.value.identity_validation_expression
  authorizer_result_ttl_in_seconds = each.value.authorizer_result_ttl_in_seconds
}

# Request Validators
resource "aws_api_gateway_request_validator" "this" {
  for_each = var.create_rest_api ? var.request_validators : {}

  rest_api_id                 = local.rest_api_id
  name                        = coalesce(each.value.name, each.key)
  validate_request_body       = each.value.validate_request_body
  validate_request_parameters = each.value.validate_request_parameters
}

# Models
resource "aws_api_gateway_model" "this" {
  for_each = var.create_rest_api ? var.models : {}

  rest_api_id  = local.rest_api_id
  name         = coalesce(each.value.name, each.key)
  content_type = each.value.content_type
  description  = each.value.description
  schema       = each.value.schema
}

# Gateway Responses
resource "aws_api_gateway_gateway_response" "this" {
  for_each = var.create_rest_api ? var.gateway_responses : {}

  rest_api_id         = local.rest_api_id
  response_type       = each.key
  status_code         = each.value.status_code
  response_parameters = each.value.response_parameters
  response_templates  = each.value.response_templates
}

# Methods
resource "aws_api_gateway_method" "this" {
  for_each = var.create_rest_api ? var.methods : {}

  rest_api_id          = local.rest_api_id
  resource_id          = local.resource_ids[each.value.path]
  http_method          = each.value.http_method
  authorization        = each.value.authorization
  authorizer_id        = each.value.authorizer_key != null ? aws_api_gateway_authorizer.this[each.value.authorizer_key].id : each.value.authorizer_id
  authorization_scopes = each.value.authorization_scopes
  api_key_required     = each.value.api_key_required
  operation_name       = each.value.operation_name
  request_models       = each.value.request_models
  request_parameters   = each.value.request_parameters
  request_validator_id = each.value.request_validator_key != null ? aws_api_gateway_request_validator.this[each.value.request_validator_key].id : null

  depends_on = [aws_api_gateway_model.this]
}

# Integrations
resource "aws_api_gateway_integration" "this" {
  for_each = var.create_rest_api ? var.methods : {}

  rest_api_id             = local.rest_api_id
  resource_id             = aws_api_gateway_method.this[each.key].resource_id
  http_method             = aws_api_gateway_method.this[each.key].http_method
  type                    = each.value.integration.type
  integration_http_method = each.value.integration.integration_http_method
  uri                     = each.value.integration.uri
  connection_type         = each.value.integration.vpc_link != null || each.value.integration.connection_id != null ? "VPC_LINK" : each.value.integration.connection_type
  connection_id           = each.value.integration.vpc_link != null ? local.vpc_link_ids[each.value.integration.vpc_link] : each.value.integration.connection_id
  integration_target      = each.value.integration.integration_target
  credentials             = each.value.integration.credentials
  request_parameters      = each.value.integration.request_parameters
  request_templates       = each.value.integration.request_templates
  passthrough_behavior    = each.value.integration.passthrough_behavior
  cache_key_parameters    = each.value.integration.cache_key_parameters
  cache_namespace         = each.value.integration.cache_namespace
  content_handling        = each.value.integration.content_handling
  timeout_milliseconds    = each.value.integration.timeout_milliseconds
  response_transfer_mode  = each.value.integration.response_transfer_mode

  dynamic "tls_config" {
    for_each = each.value.integration.insecure_skip_verification != null ? [1] : []

    content {
      insecure_skip_verification = each.value.integration.insecure_skip_verification
    }
  }

  lifecycle {
    precondition {
      condition     = each.value.integration.vpc_link != "v2" || each.value.integration.integration_target != null
      error_message = "A VPC Link v2 integration needs integration_target (the ALB or NLB ARN)."
    }
  }
}

# Method Responses
resource "aws_api_gateway_method_response" "this" {
  for_each = var.create_rest_api ? local.method_responses : {}

  rest_api_id         = local.rest_api_id
  resource_id         = aws_api_gateway_method.this[each.value.method_key].resource_id
  http_method         = aws_api_gateway_method.this[each.value.method_key].http_method
  status_code         = each.value.status_code
  response_models     = each.value.response_models
  response_parameters = each.value.response_parameters
}

# Integration Responses
resource "aws_api_gateway_integration_response" "this" {
  for_each = var.create_rest_api ? local.integration_responses : {}

  rest_api_id         = local.rest_api_id
  resource_id         = aws_api_gateway_method.this[each.value.method_key].resource_id
  http_method         = aws_api_gateway_method.this[each.value.method_key].http_method
  status_code         = each.value.status_code
  selection_pattern   = each.value.selection_pattern
  response_parameters = each.value.response_parameters
  response_templates  = each.value.response_templates
  content_handling    = each.value.content_handling

  depends_on = [
    aws_api_gateway_integration.this,
    aws_api_gateway_method_response.this
  ]
}

# Deployment
resource "aws_api_gateway_deployment" "this" {
  count = var.create_rest_api && var.create_deployment ? 1 : 0

  rest_api_id = local.rest_api_id
  description = var.deployment_description

  triggers = {
    redeployment = local.redeployment_hash
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.this,
    aws_api_gateway_integration.this,
    aws_api_gateway_method_response.this,
    aws_api_gateway_integration_response.this,
    aws_api_gateway_gateway_response.this,
    aws_api_gateway_rest_api_policy.this
  ]
}

# CloudWatch Logs Role for API Gateway, account-level setting per Region (toggle: create_cloudwatch_role)
data "aws_iam_policy_document" "cloudwatch_assume_role" {
  count = var.create_rest_api && var.create_cloudwatch_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudwatch" {
  count = var.create_rest_api && var.create_cloudwatch_role ? 1 : 0

  name               = coalesce(var.cloudwatch_role_name, "${var.name}-apigw-cloudwatch-role")
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_assume_role[0].json

  tags = merge(
    var.tags,
    { Name = coalesce(var.cloudwatch_role_name, "${var.name}-apigw-cloudwatch-role") }
  )
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  count = var.create_rest_api && var.create_cloudwatch_role ? 1 : 0

  role       = aws_iam_role.cloudwatch[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "this" {
  count = var.create_rest_api && var.create_cloudwatch_role ? 1 : 0

  cloudwatch_role_arn = aws_iam_role.cloudwatch[0].arn

  depends_on = [aws_iam_role_policy_attachment.cloudwatch]
}

# Access Log Groups (toggle: stages.access_log.create_log_group)
resource "aws_cloudwatch_log_group" "access" {
  for_each = var.create_rest_api ? local.access_log_groups : {}

  name              = coalesce(each.value.log_group_name, "/aws/apigateway/${var.name}/${coalesce(var.stages[each.key].stage_name, each.key)}")
  retention_in_days = each.value.retention_in_days
  kms_key_id        = each.value.kms_key_id

  tags = merge(
    var.tags,
    { Name = coalesce(each.value.log_group_name, "/aws/apigateway/${var.name}/${coalesce(var.stages[each.key].stage_name, each.key)}") }
  )
}

# Execution Log Groups, pre-created so retention is managed (toggle: stages.create_execution_log_group)
resource "aws_cloudwatch_log_group" "execution" {
  for_each = var.create_rest_api ? { for k, s in var.stages : k => s if s.create_execution_log_group } : {}

  name              = "API-Gateway-Execution-Logs_${local.rest_api_id}/${coalesce(each.value.stage_name, each.key)}"
  retention_in_days = each.value.execution_log_retention_in_days
  kms_key_id        = each.value.execution_log_kms_key_id

  tags = merge(
    var.tags,
    { Name = "API-Gateway-Execution-Logs_${local.rest_api_id}/${coalesce(each.value.stage_name, each.key)}" }
  )
}

# Stages
resource "aws_api_gateway_stage" "this" {
  for_each = var.create_rest_api && var.create_deployment ? var.stages : {}

  rest_api_id           = local.rest_api_id
  deployment_id         = aws_api_gateway_deployment.this[0].id
  stage_name            = coalesce(each.value.stage_name, each.key)
  description           = each.value.description
  variables             = each.value.variables
  xray_tracing_enabled  = each.value.xray_tracing_enabled
  cache_cluster_enabled = each.value.cache_cluster_enabled
  cache_cluster_size    = each.value.cache_cluster_enabled ? each.value.cache_cluster_size : null
  client_certificate_id = each.value.client_certificate_id
  documentation_version = each.value.documentation_version

  dynamic "access_log_settings" {
    for_each = each.value.access_log != null ? [each.value.access_log] : []

    content {
      destination_arn = access_log_settings.value.create_log_group ? aws_cloudwatch_log_group.access[each.key].arn : access_log_settings.value.destination_arn
      format          = access_log_settings.value.format
    }
  }

  dynamic "canary_settings" {
    for_each = each.value.canary_settings != null ? [each.value.canary_settings] : []

    content {
      deployment_id            = canary_settings.value.deployment_id
      percent_traffic          = canary_settings.value.percent_traffic
      stage_variable_overrides = canary_settings.value.stage_variable_overrides
      use_stage_cache          = canary_settings.value.use_stage_cache
    }
  }

  tags = merge(
    var.tags,
    each.value.tags,
    { Name = "${var.name}-${coalesce(each.value.stage_name, each.key)}" }
  )

  depends_on = [
    aws_api_gateway_account.this,
    aws_cloudwatch_log_group.execution
  ]
}

# Method Settings (throttling, logging, metrics, caching per stage)
resource "aws_api_gateway_method_settings" "this" {
  for_each = var.create_rest_api && var.create_deployment ? local.method_settings : {}

  rest_api_id = local.rest_api_id
  stage_name  = aws_api_gateway_stage.this[each.value.stage_key].stage_name
  method_path = each.value.method_path

  settings {
    metrics_enabled                            = each.value.metrics_enabled
    logging_level                              = each.value.logging_level
    data_trace_enabled                         = each.value.data_trace_enabled
    throttling_burst_limit                     = each.value.throttling_burst_limit
    throttling_rate_limit                      = each.value.throttling_rate_limit
    caching_enabled                            = each.value.caching_enabled
    cache_ttl_in_seconds                       = each.value.cache_ttl_in_seconds
    cache_data_encrypted                       = each.value.cache_data_encrypted
    require_authorization_for_cache_control    = each.value.require_authorization_for_cache_control
    unauthorized_cache_control_header_strategy = each.value.unauthorized_cache_control_header_strategy
  }
}

# API Keys
resource "aws_api_gateway_api_key" "this" {
  for_each = var.create_rest_api ? var.api_keys : {}

  name        = coalesce(each.value.name, each.key)
  description = each.value.description
  enabled     = each.value.enabled
  customer_id = each.value.customer_id
  value       = lookup(var.api_key_values, each.key, null)

  tags = merge(
    var.tags,
    each.value.tags,
    { Name = coalesce(each.value.name, each.key) }
  )
}

# Usage Plans
resource "aws_api_gateway_usage_plan" "this" {
  for_each = var.create_rest_api && var.create_deployment ? var.usage_plans : {}

  name         = coalesce(each.value.name, each.key)
  description  = each.value.description
  product_code = each.value.product_code

  dynamic "api_stages" {
    for_each = each.value.stages

    content {
      api_id = local.rest_api_id
      stage  = aws_api_gateway_stage.this[api_stages.value.stage_key].stage_name

      dynamic "throttle" {
        for_each = api_stages.value.method_throttles

        content {
          path        = throttle.value.path
          burst_limit = throttle.value.burst_limit
          rate_limit  = throttle.value.rate_limit
        }
      }
    }
  }

  dynamic "quota_settings" {
    for_each = each.value.quota_settings != null ? [each.value.quota_settings] : []

    content {
      limit  = quota_settings.value.limit
      period = quota_settings.value.period
      offset = quota_settings.value.offset
    }
  }

  dynamic "throttle_settings" {
    for_each = each.value.throttle_settings != null ? [each.value.throttle_settings] : []

    content {
      burst_limit = throttle_settings.value.burst_limit
      rate_limit  = throttle_settings.value.rate_limit
    }
  }

  tags = merge(
    var.tags,
    each.value.tags,
    { Name = coalesce(each.value.name, each.key) }
  )
}

# Usage Plan Keys
resource "aws_api_gateway_usage_plan_key" "this" {
  for_each = var.create_rest_api && var.create_deployment ? local.usage_plan_keys : {}

  usage_plan_id = aws_api_gateway_usage_plan.this[each.value.plan_key].id
  key_id        = aws_api_gateway_api_key.this[each.value.api_key_key].id
  key_type      = "API_KEY"
}

# Custom Domain (toggle: custom_domain)
resource "aws_api_gateway_domain_name" "this" {
  count = var.create_rest_api && var.custom_domain != null ? 1 : 0

  domain_name                            = var.custom_domain.domain_name
  regional_certificate_arn               = var.custom_domain.endpoint_type == "REGIONAL" ? var.custom_domain.certificate_arn : null
  certificate_arn                        = var.custom_domain.endpoint_type == "EDGE" ? var.custom_domain.certificate_arn : null
  regional_certificate_name              = var.custom_domain.regional_certificate_name
  certificate_name                       = var.custom_domain.certificate_name
  security_policy                        = var.custom_domain.security_policy
  endpoint_access_mode                   = var.custom_domain.endpoint_access_mode
  routing_mode                           = var.custom_domain.routing_mode
  ownership_verification_certificate_arn = var.custom_domain.ownership_verification_certificate_arn
  policy                                 = var.custom_domain.policy

  endpoint_configuration {
    types           = [var.custom_domain.endpoint_type]
    ip_address_type = var.custom_domain.ip_address_type
  }

  dynamic "mutual_tls_authentication" {
    for_each = var.custom_domain.truststore_uri != null ? [1] : []

    content {
      truststore_uri     = var.custom_domain.truststore_uri
      truststore_version = var.custom_domain.truststore_version
    }
  }

  tags = merge(
    var.tags,
    { Name = var.custom_domain.domain_name }
  )
}

resource "aws_api_gateway_base_path_mapping" "this" {
  for_each = var.create_rest_api && var.create_deployment && var.custom_domain != null ? var.custom_domain.base_path_mappings : {}

  api_id      = local.rest_api_id
  domain_name = aws_api_gateway_domain_name.this[0].domain_name
  stage_name  = aws_api_gateway_stage.this[each.value.stage_key].stage_name
  base_path   = each.value.base_path
}
