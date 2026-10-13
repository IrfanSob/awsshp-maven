output "event_bus_name" {
  description = "Event bus the rules are attached to (null = default bus)"
  value       = local.event_bus_name
}

output "event_bus_arn" {
  description = "Custom event bus ARN when created here"
  value       = one(aws_cloudwatch_event_bus.this[*].arn)
}

output "rule_arns" {
  description = "Map of rule keys to rule ARNs"
  value       = { for k, v in aws_cloudwatch_event_rule.this : k => v.arn }
}

output "rule_names" {
  description = "Map of rule keys to rule names"
  value       = { for k, v in aws_cloudwatch_event_rule.this : k => v.name }
}
