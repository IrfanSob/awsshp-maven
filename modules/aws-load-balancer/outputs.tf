output "lb_id" {
  description = "ID of the load balancer"
  value       = aws_lb.this.id
}

output "lb_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.this.arn
}

output "lb_arn_suffix" {
  description = "ARN suffix of the load balancer, used in CloudWatch metric dimensions"
  value       = aws_lb.this.arn_suffix
}

output "lb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.this.dns_name
}

output "lb_zone_id" {
  description = "Route 53 hosted zone ID of the load balancer, for alias records"
  value       = aws_lb.this.zone_id
}

output "target_group_arns" {
  description = "Map of target group keys to their ARNs"
  value = {
    for k, v in aws_lb_target_group.this : k => v.arn
  }
}

output "target_group_names" {
  description = "Map of target group keys to their names"
  value = {
    for k, v in aws_lb_target_group.this : k => v.name
  }
}

output "target_group_arn_suffixes" {
  description = "Map of target group keys to their ARN suffixes, used in CloudWatch metric dimensions"
  value = {
    for k, v in aws_lb_target_group.this : k => v.arn_suffix
  }
}

output "listener_arns" {
  description = "Map of listener keys to their ARNs"
  value       = local.listener_arns
}

output "listener_rule_arns" {
  description = "Map of listener rule keys to their ARNs"
  value = {
    for k, v in aws_lb_listener_rule.this : k => v.arn
  }
}
