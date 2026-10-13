output "public_route_table_id" {
  description = "ID of the public route table (or null if not created)."
  value       = try(aws_route_table.public[0].id, null)
}

output "private_app_route_table_id" {
  description = "ID of the private app route table (or null if not created)."
  value       = try(aws_route_table.private_app[0].id, null)
}

output "private_db_route_table_id" {
  description = "ID of the private db route table (or null if not created)."
  value       = try(aws_route_table.private_db[0].id, null)
}

output "other_private_subnets_first_route_table_id" {
  description = "ID of the first other private subnets route table (or null if not created)."
  value       = try(aws_route_table.other_private_subnets_first[0].id, null)
}

output "other_private_subnets_second_route_table_id" {
  description = "ID of the second other private subnets route table (or null if not created)."
  value       = try(aws_route_table.other_private_subnets_second[0].id, null)
}

output "other_private_subnets_third_route_table_id" {
  description = "ID of the third other private subnets route table (or null if not created)."
  value       = try(aws_route_table.other_private_subnets_third[0].id, null)
}

output "transit_gateway_route_table_id" {
  description = "ID of the transit gateway route table (or null if not created)."
  value       = try(aws_route_table.transit_gateway[0].id, null)
}

output "public_default_route_id" {
  description = "ID of the default route in the public route table (if created)."
  value       = try(aws_route.public_route[0].id, null)
}

output "private_app_nat_route_id" {
  description = "ID of the NAT default route in the private app route table (if created)."
  value       = try(aws_route.private_app_nat_route[0].id, null)
}

output "private_db_nat_route_id" {
  description = "ID of the NAT default route in the private db route table (if created)."
  value       = try(aws_route.private_db_nat_route[0].id, null)
}

output "other_private_subnets_first_nat_route_id" {
  description = "ID of the NAT default route in the first other private subnets route table (if created)."
  value       = try(aws_route.other_private_subnets_first_nat_route[0].id, null)
}

output "other_private_subnets_second_nat_route_id" {
  description = "ID of the NAT default route in the second other private subnets route table (if created)."
  value       = try(aws_route.other_private_subnets_second_nat_route[0].id, null)
}

output "other_private_subnets_third_nat_route_id" {
  description = "ID of the NAT default route in the third other private subnets route table (if created)."
  value       = try(aws_route.other_private_subnets_third_nat_route[0].id, null)
}