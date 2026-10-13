output "application_name" {
  description = "CodeDeploy application name"
  value       = local.application_name
}

output "application_arn" {
  description = "CodeDeploy application ARN when created here"
  value       = one(aws_codedeploy_app.this[*].arn)
}

output "service_role_arn" {
  description = "Service role ARN in use"
  value       = local.service_role_arn
}

output "deployment_group_names" {
  description = "Map of deployment group keys to names"
  value       = { for k, v in aws_codedeploy_deployment_group.this : k => v.deployment_group_name }
}

output "deployment_group_arns" {
  description = "Map of deployment group keys to ARNs"
  value       = { for k, v in aws_codedeploy_deployment_group.this : k => v.arn }
}

output "deployment_config_names" {
  description = "Map of custom deployment config keys to names"
  value       = { for k, v in aws_codedeploy_deployment_config.this : k => v.deployment_config_name }
}
