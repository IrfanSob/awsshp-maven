output "trail_arn" {
  value = aws_cloudtrail.this.arn
}

output "trail_name" {
  value = aws_cloudtrail.this.name
}

output "bucket_name" {
  value = local.s3_bucket_name
}

output "bucket_arn" {
  value = local.s3_bucket_arn
}

output "cloudwatch_log_group_name" {
  value = one(aws_cloudwatch_log_group.this[*].name)
}

output "cloudwatch_log_group_arn" {
  value = one(aws_cloudwatch_log_group.this[*].arn)
}

output "cloudwatch_logs_role_arn" {
  value = one(aws_iam_role.cloudwatch_logs[*].arn)
}
