output "project_name" {
  description = "CodeBuild project name, used by start-build"
  value       = one(aws_codebuild_project.this[*].name)
}

output "project_arn" {
  description = "CodeBuild project ARN"
  value       = one(aws_codebuild_project.this[*].arn)
}

output "badge_url" {
  description = "Build badge URL when badge_enabled is true"
  value       = one(aws_codebuild_project.this[*].badge_url)
}

output "service_role_arn" {
  description = "Service role ARN in use"
  value       = local.service_role_arn
}

output "service_role_name" {
  description = "Service role name when created here"
  value       = one(aws_iam_role.this[*].name)
}

output "log_group_name" {
  description = "Build log group name"
  value       = local.log_group_name
}

output "webhook_payload_url" {
  description = "Webhook payload URL"
  value       = one(aws_codebuild_webhook.this[*].payload_url)
}

output "webhook_secret" {
  description = "Webhook secret"
  value       = one(aws_codebuild_webhook.this[*].secret)
  sensitive   = true
}
