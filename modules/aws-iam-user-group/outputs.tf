output "group_name" {
  description = "Name of the IAM group in use, whether created here or pre-existing"
  value       = local.group_name
}

output "group_arn" {
  description = "ARN of the IAM group (null when the group is not created by this module)"
  value       = one(aws_iam_group.this[*].arn)
}

output "group_id" {
  description = "ID of the IAM group (null when the group is not created by this module)"
  value       = one(aws_iam_group.this[*].id)
}

output "group_unique_id" {
  description = "Unique ID assigned by AWS to the IAM group (null when the group is not created by this module)"
  value       = one(aws_iam_group.this[*].unique_id)
}

output "user_names" {
  description = "Map of user keys to their IAM user names"
  value = {
    for k, v in aws_iam_user.this : k => v.name
  }
}

output "user_arns" {
  description = "Map of user keys to their IAM user ARNs"
  value = {
    for k, v in aws_iam_user.this : k => v.arn
  }
}

output "user_unique_ids" {
  description = "Map of user keys to the unique IDs assigned by AWS"
  value = {
    for k, v in aws_iam_user.this : k => v.unique_id
  }
}

output "customer_managed_policy_arns" {
  description = "Map of created customer managed policy names to their ARNs"
  value = {
    for k, v in aws_iam_policy.this : k => v.arn
  }
}

output "customer_managed_policy_ids" {
  description = "Map of created customer managed policy names to their policy IDs"
  value = {
    for k, v in aws_iam_policy.this : k => v.policy_id
  }
}

output "inline_policy_names" {
  description = "Names of the inline policies embedded in the group"
  value       = keys(aws_iam_group_policy.inline)
}
