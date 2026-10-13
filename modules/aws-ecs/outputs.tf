output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.this.id
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.this.name
}

output "capacity_providers" {
  description = "Capacity providers attached to the cluster"
  value       = local.all_capacity_providers
}

output "ec2_capacity_provider_name" {
  description = "Name of the EC2 capacity provider, null when it is not created"
  value       = one(aws_ecs_capacity_provider.ec2[*].name)
}

output "ec2_autoscaling_group_name" {
  description = "Auto Scaling group backing the EC2 capacity provider"
  value       = one(aws_autoscaling_group.ec2[*].name)
}

output "ec2_autoscaling_group_arn" {
  description = "ARN of the Auto Scaling group backing the EC2 capacity provider"
  value       = one(aws_autoscaling_group.ec2[*].arn)
}

output "ec2_launch_template_id" {
  description = "Launch template used by the container instances"
  value       = one(aws_launch_template.ec2[*].id)
}

output "ec2_instance_role_arn" {
  description = "Container instance role ARN"
  value       = one(aws_iam_role.ec2[*].arn)
}

output "ec2_instance_profile_name" {
  description = "Container instance profile name"
  value       = local.instance_profile_name
}

output "task_execution_role_arn" {
  description = "Task execution role ARN in use"
  value       = local.task_execution_role_arn
}

output "task_role_arn" {
  description = "Task role ARN in use"
  value       = local.task_role_arn
}

output "service_connect_namespace_arn" {
  description = "Cloud Map namespace ARN used for Service Connect"
  value       = local.service_connect_namespace_arn
}

output "service_connect_namespace_id" {
  description = "Cloud Map namespace ID, null when the namespace is not created here"
  value       = one(aws_service_discovery_http_namespace.this[*].id)
}

output "task_definition_arns" {
  description = "Task definition ARNs keyed by task definition name"
  value       = { for key, td in aws_ecs_task_definition.this : key => td.arn }
}

output "task_definition_families" {
  description = "Task definition families keyed by task definition name"
  value       = { for key, td in aws_ecs_task_definition.this : key => td.family }
}

output "service_names" {
  description = "Service names keyed by service key"
  value       = { for key, svc in aws_ecs_service.this : key => svc.name }
}

output "service_arns" {
  description = "Service ARNs keyed by service key"
  value       = { for key, svc in aws_ecs_service.this : key => svc.id }
}

output "task_log_group_names" {
  description = "Task log groups created by this module"
  value       = { for key, lg in aws_cloudwatch_log_group.tasks : key => lg.name }
}

output "execute_command_log_group_name" {
  description = "ECS Exec log group name, null when not created"
  value       = one(aws_cloudwatch_log_group.exec[*].name)
}

output "ec2_key_pair_name" {
  description = "Name of the generated container instance key pair"
  value       = one(aws_key_pair.ec2[*].key_name)
}

output "ec2_ssh_private_key_s3_path" {
  description = "S3 location of the generated private key"
  value       = one([for obj in aws_s3_object.ec2_private_key : "s3://${obj.bucket}/${obj.key}"])
}

output "ec2_ssh_public_key_s3_path" {
  description = "S3 location of the generated public key"
  value       = one([for obj in aws_s3_object.ec2_public_key : "s3://${obj.bucket}/${obj.key}"])
}
