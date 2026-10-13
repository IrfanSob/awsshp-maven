output "web_acl_id" {
  description = "WAF Web ACL ID"
  value       = aws_wafv2_web_acl.this.id
}

output "web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_name" {
  description = "WAF Web ACL name"
  value       = aws_wafv2_web_acl.this.name
}

output "web_acl_capacity" {
  description = "WAF Web ACL capacity"
  value       = aws_wafv2_web_acl.this.capacity
}

output "web_acl_lock_token" {
  description = "WAF Web ACL lock token"
  value       = aws_wafv2_web_acl.this.lock_token
}

output "association_id" {
  description = "WAF Web ACL association ID"
  value       = var.create_web_acl_association ? aws_wafv2_web_acl_association.this[0].id : null
}

output "log_group_name" {
  description = "WAF CloudWatch Log Group name"
  value       = var.enable_logging && var.create_log_group ? aws_cloudwatch_log_group.waf[0].name : null
}

output "log_group_arn" {
  description = "WAF CloudWatch Log Group ARN"
  value       = var.enable_logging && var.create_log_group ? aws_cloudwatch_log_group.waf[0].arn : null
}