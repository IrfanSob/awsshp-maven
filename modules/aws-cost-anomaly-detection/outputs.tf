output "monitor_arns" {
  description = "Anomaly monitor ARNs keyed by monitor name"
  value       = { for key, monitor in aws_ce_anomaly_monitor.this : key => monitor.arn }
}

output "monitor_ids" {
  description = "Anomaly monitor IDs keyed by monitor name"
  value       = { for key, monitor in aws_ce_anomaly_monitor.this : key => monitor.id }
}

output "subscription_arns" {
  description = "Anomaly subscription ARNs keyed by subscription name"
  value       = { for key, subscription in aws_ce_anomaly_subscription.this : key => subscription.arn }
}

output "sns_topic_arn" {
  description = "SNS topic used for anomaly alerts, created or supplied"
  value       = local.sns_topic_arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic created by this module, null when not created"
  value       = one(aws_sns_topic.this[*].name)
}
