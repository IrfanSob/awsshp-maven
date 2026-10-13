output "secret_arns" {
  description = "Map of secret keys to secret ARNs"
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.arn }
}

output "secret_ids" {
  description = "Map of secret keys to secret IDs"
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.id }
}

output "secret_names" {
  description = "Map of secret keys to secret names"
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.name }
}

output "secret_version_ids" {
  description = "Map of secret keys to the version ID written by Terraform"
  value       = local.version_ids
}

output "generated_passwords" {
  description = "Map of secret keys to generated passwords, for resources that need the raw value (e.g. an ElastiCache AUTH token)"
  value       = { for k, v in random_password.this : k => v.result }
  sensitive   = true
}
