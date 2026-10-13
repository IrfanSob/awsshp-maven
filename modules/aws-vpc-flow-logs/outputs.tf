output "log_group_name" {
  value = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  value = aws_cloudwatch_log_group.this.arn
}

output "flow_log_id" {
  value = aws_flow_log.this.id
}

output "iam_role_arn" {
  value = aws_iam_role.this.arn
}