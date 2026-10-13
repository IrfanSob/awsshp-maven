# --- REST API ------------------------------------------------------------------

output "rest_api_id" {
  description = "REST API ID"
  value       = local.rest_api_id
}

output "rest_api_arn" {
  description = "REST API ARN"
  value       = one(aws_api_gateway_rest_api.this[*].arn)
}

output "rest_api_execution_arn" {
  description = "Execution ARN, used in Lambda permissions and IAM policies"
  value       = one(aws_api_gateway_rest_api.this[*].execution_arn)
}

output "resource_ids" {
  description = "Map of resource paths to resource IDs"
  value       = local.resource_ids
}

output "vpc_link_v2_id" {
  description = "VPC Link v2 ID"
  value       = one(aws_apigatewayv2_vpc_link.this[*].id)
}

output "authorizer_ids" {
  description = "Map of authorizer keys to authorizer IDs"
  value       = { for k, v in aws_api_gateway_authorizer.this : k => v.id }
}

# --- Deployment and stages -----------------------------------------------------

output "deployment_id" {
  description = "Current deployment ID"
  value       = one(aws_api_gateway_deployment.this[*].id)
}

output "stage_invoke_urls" {
  description = "Map of stage keys to invoke URLs"
  value       = { for k, v in aws_api_gateway_stage.this : k => v.invoke_url }
}

output "stage_arns" {
  description = "Map of stage keys to stage ARNs, used for WAF web ACL association"
  value       = { for k, v in aws_api_gateway_stage.this : k => v.arn }
}

output "access_log_group_arns" {
  description = "Map of stage keys to access log group ARNs created here"
  value       = { for k, v in aws_cloudwatch_log_group.access : k => v.arn }
}

# --- API keys and usage plans --------------------------------------------------

output "api_key_ids" {
  description = "Map of API key keys to API key IDs"
  value       = { for k, v in aws_api_gateway_api_key.this : k => v.id }
}

output "api_key_values" {
  description = "Map of API key keys to API key values"
  value       = { for k, v in aws_api_gateway_api_key.this : k => v.value }
  sensitive   = true
}

output "usage_plan_ids" {
  description = "Map of usage plan keys to usage plan IDs"
  value       = { for k, v in aws_api_gateway_usage_plan.this : k => v.id }
}

# --- Custom domain -------------------------------------------------------------

output "custom_domain_regional_domain_name" {
  description = "Target hostname for the DNS record of a REGIONAL custom domain"
  value       = one(aws_api_gateway_domain_name.this[*].regional_domain_name)
}

output "custom_domain_regional_zone_id" {
  description = "Hosted zone ID for an alias record of a REGIONAL custom domain"
  value       = one(aws_api_gateway_domain_name.this[*].regional_zone_id)
}

output "custom_domain_cloudfront_domain_name" {
  description = "Target hostname for the DNS record of an EDGE custom domain"
  value       = one(aws_api_gateway_domain_name.this[*].cloudfront_domain_name)
}
