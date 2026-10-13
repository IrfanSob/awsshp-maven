output "backup_vault_name" {
  description = "AWS Backup vault name"
  value       = aws_backup_vault.this.name
}

output "backup_vault_arn" {
  description = "AWS Backup vault ARN"
  value       = aws_backup_vault.this.arn
}

output "backup_plan_id" {
  description = "AWS Backup plan ID"
  value       = aws_backup_plan.this.id
}

output "backup_plan_arn" {
  description = "AWS Backup plan ARN"
  value       = aws_backup_plan.this.arn
}

output "backup_plan_version" {
  description = "AWS Backup plan version"
  value       = aws_backup_plan.this.version
}

output "backup_selection_ids" {
  description = "AWS Backup selection IDs"
  value = {
    for k, v in aws_backup_selection.this : k => v.id
  }
}

output "iam_role_arn" {
  description = "AWS Backup IAM role ARN"
  value       = var.create_iam_role ? aws_iam_role.this[0].arn : var.existing_iam_role_arn
}

output "sns_topic_arn" {
  description = "SNS topic ARN for backup notifications"
  value       = var.create_sns_topic ? aws_sns_topic.this[0].arn : var.existing_sns_topic_arn
}
output "backup_vault_policy_id" {
  description = "ID of the vault access policy, or null when create_vault_policy is false"
  value       = one(aws_backup_vault_policy.this[*].id)
}
