output "metric_alarm_arns" {
  description = "Map of metric alarm keys to ARNs"
  value       = { for k, v in aws_cloudwatch_metric_alarm.this : k => v.arn }
}

output "metric_alarm_names" {
  description = "Map of metric alarm keys to names, e.g. for CodeDeploy alarm_configuration"
  value       = { for k, v in aws_cloudwatch_metric_alarm.this : k => v.alarm_name }
}

output "composite_alarm_arns" {
  description = "Map of composite alarm keys to ARNs"
  value       = { for k, v in aws_cloudwatch_composite_alarm.this : k => v.arn }
}

output "log_metric_filter_names" {
  description = "Map of log metric filter keys to names"
  value       = { for k, v in aws_cloudwatch_log_metric_filter.this : k => v.name }
}
