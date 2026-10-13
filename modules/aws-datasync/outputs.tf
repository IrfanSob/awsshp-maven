output "location_arns" {
  description = "All location ARNs keyed by <type>.<location key>"
  value       = local.location_arns
}

output "s3_location_arns" {
  description = "S3 location ARNs keyed by location name"
  value       = { for key, location in aws_datasync_location_s3.this : key => location.arn }
}

output "nfs_location_arns" {
  description = "NFS location ARNs keyed by location name"
  value       = { for key, location in aws_datasync_location_nfs.this : key => location.arn }
}

output "smb_location_arns" {
  description = "SMB location ARNs keyed by location name"
  value       = { for key, location in aws_datasync_location_smb.this : key => location.arn }
}

output "efs_location_arns" {
  description = "EFS location ARNs keyed by location name"
  value       = { for key, location in aws_datasync_location_efs.this : key => location.arn }
}

output "s3_iam_role_arns" {
  description = "IAM roles created for S3 locations, keyed by location name"
  value       = { for key, role in aws_iam_role.s3 : key => role.arn }
}

output "agent_arns" {
  description = "Agent ARNs keyed by agent name"
  value       = { for key, agent in aws_datasync_agent.this : key => agent.arn }
}

output "task_arns" {
  description = "Task ARNs keyed by task name"
  value       = { for key, task in aws_datasync_task.this : key => task.arn }
}

output "task_names" {
  description = "Task names keyed by task name"
  value       = { for key, task in aws_datasync_task.this : key => task.name }
}

output "task_log_group_names" {
  description = "CloudWatch log groups created for tasks"
  value       = local.task_log_group_names
}
