output "security_group_id" {
  description = "Created shared security group ID"
  value       = var.create_security_group ? aws_security_group.this[0].id : null
}

output "endpoint_ids" {
  description = "Map of endpoint IDs"
  value = {
    for k, v in aws_vpc_endpoint.this : k => v.id
  }
}

output "endpoint_arns" {
  description = "Map of endpoint ARNs"
  value = {
    for k, v in aws_vpc_endpoint.this : k => v.arn
  }
}

output "endpoint_dns_entries" {
  description = "Map of endpoint DNS entries"
  value = {
    for k, v in aws_vpc_endpoint.this : k => v.dns_entry
  }
}

output "endpoint_network_interface_ids" {
  description = "Map of endpoint ENI IDs"
  value = {
    for k, v in aws_vpc_endpoint.this : k => v.network_interface_ids
  }
}