# --- User pool -----------------------------------------------------------------

output "user_pool_id" {
  description = "User pool ID"
  value       = local.user_pool_id
}

output "user_pool_arn" {
  description = "User pool ARN, used by API Gateway Cognito authorizers"
  value       = one(aws_cognito_user_pool.this[*].arn)
}

output "user_pool_endpoint" {
  description = "User pool endpoint (issuer host)"
  value       = one(aws_cognito_user_pool.this[*].endpoint)
}

# --- Domain --------------------------------------------------------------------

output "domain" {
  description = "Domain prefix or custom domain"
  value       = one(aws_cognito_user_pool_domain.this[*].domain)
}

output "domain_cloudfront_distribution" {
  description = "CloudFront target for the DNS record of a custom domain"
  value       = one(aws_cognito_user_pool_domain.this[*].cloudfront_distribution)
}

output "oauth2_token_url" {
  description = "OAuth2 token endpoint (TOKEN_URL for client_credentials)"
  value       = local.domain_base_url != null ? "${local.domain_base_url}/oauth2/token" : null
}

# --- Clients and resource servers ----------------------------------------------

output "client_ids" {
  description = "Map of client keys to client IDs"
  value       = { for k, v in aws_cognito_user_pool_client.this : k => v.id }
}

output "client_secrets" {
  description = "Map of client keys to client secrets"
  value       = { for k, v in aws_cognito_user_pool_client.this : k => v.client_secret }
  sensitive   = true
}

output "resource_server_scope_identifiers" {
  description = "Map of resource server keys to their full scope identifiers (<identifier>/<scope>)"
  value       = { for k, v in aws_cognito_resource_server.this : k => v.scope_identifiers }
}

output "user_group_names" {
  description = "Map of user group keys to group names"
  value       = { for k, v in aws_cognito_user_group.this : k => v.name }
}
