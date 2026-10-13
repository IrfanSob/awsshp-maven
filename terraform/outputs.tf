# Site-to-Site VPN (Kalbe side configuration, AF 3.9)
output "vpn_tunnels" {
  description = "AWS tunnel endpoints and inside addresses for the Kalbe VPN device"
  value = local.vpn_enabled ? {
    tunnel1 = {
      outside_ip = module.vpn_onprem[0].tunnel1_address
      cgw_inside = module.vpn_onprem[0].tunnel1_cgw_inside_address
      vgw_inside = module.vpn_onprem[0].tunnel1_vgw_inside_address
    }
    tunnel2 = {
      outside_ip = module.vpn_onprem[0].tunnel2_address
      cgw_inside = module.vpn_onprem[0].tunnel2_cgw_inside_address
      vgw_inside = module.vpn_onprem[0].tunnel2_vgw_inside_address
    }
  } : null
}

output "vpn_preshared_keys" {
  description = "Tunnel preshared keys for the Kalbe VPN device"
  value = local.vpn_enabled ? {
    tunnel1 = module.vpn_onprem[0].tunnel1_preshared_key
    tunnel2 = module.vpn_onprem[0].tunnel2_preshared_key
  } : null
  sensitive = true
}

# Application environment (TOKEN_URL, CLIENT_ID, CLIENT_SECRET, API endpoint, AF 8.6)
output "cognito_token_url" {
  description = "OAuth2 token endpoint (TOKEN_URL)"
  value       = module.cognito.oauth2_token_url
}

output "cognito_client_ids" {
  description = "Cognito app client IDs per external system (CLIENT_ID)"
  value       = module.cognito.client_ids
}

output "cognito_client_secrets" {
  description = "Cognito app client secrets per external system (CLIENT_SECRET)"
  value       = module.cognito.client_secrets
  sensitive   = true
}

output "api_invoke_url" {
  description = "API Gateway stage invoke URL"
  value       = module.api_gateway.stage_invoke_urls["main"]
}

output "api_key_values" {
  description = "API keys per external system (x-api-key header)"
  value       = module.api_gateway.api_key_values
  sensitive   = true
}

# DataSync agent activation (private endpoint IP entered on the agent console)
output "datasync_endpoint_private_ip" {
  description = "Private IP of the DataSync interface endpoint"
  value       = try(data.aws_network_interface.vpce_datasync[0].private_ip, null)
}

# Container images (AF 7.3)
output "ecr_repository_urls" {
  description = "ECR repository URLs per service"
  value       = module.ecr.repository_urls
}

# Database migration (AF 4.4)
output "aurora_endpoint" {
  description = "Aurora writer endpoint for pg_restore"
  value       = module.aurora.cluster_endpoint
}

output "aurora_master_secret_arn" {
  description = "Secrets Manager ARN of the RDS-managed master credential"
  value       = module.aurora.cluster_master_user_secret_arn
}

# CI/CD (GitLab CI pipeline configuration, AF 10.2 - 10.4)
output "cicd_artifact_bucket" {
  description = "Bucket where GitLab CI uploads <service>/source.zip and the CodeDeploy AppSpec"
  value       = module.s3_cicd.bucket_id
}

output "cicd_codedeploy_application" {
  description = "CodeDeploy application name"
  value       = module.codedeploy.application_name
}

output "cicd_services" {
  description = "Per-service names used by the GitLab CI pipeline"
  value = {
    for k, s in local.services : k => {
      codebuild_project           = module.codebuild[k].project_name
      codedeploy_deployment_group = module.codedeploy.deployment_group_names[k]
      ecr_repository_url          = module.ecr.repository_urls[s.repository]
      task_definition_family      = s.name
      container_name              = k
      container_port              = s.container_port
    }
  }
}
