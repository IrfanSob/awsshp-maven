output "topic_arn" {
  description = "Topic ARN"
  value       = local.topic_arn
}

output "topic_name" {
  description = "Topic name"
  value       = one(aws_sns_topic.this[*].name)
}

output "subscription_arns" {
  description = "Map of subscription keys to subscription ARNs"
  value       = { for k, v in aws_sns_topic_subscription.this : k => v.arn }
}
