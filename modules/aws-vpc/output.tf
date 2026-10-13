output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = var.enable_igw ? aws_internet_gateway.this[0].id : null
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "List of IDs of private App subnets"
  value       = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  description = "List of IDs of private DB subnets"
  value       = aws_subnet.private_db[*].id
}

output "other_private_subnet_first_ids" {
  description = "List of IDs of other private subnets"
  value       = aws_subnet.private_other_first[*].id
}

output "other_private_subnet_second_ids" {
  description = "List of IDs of other private subnets"
  value       = aws_subnet.private_other_second[*].id
}

output "other_private_subnet_third_ids" {
  description = "List of IDs of other private subnets"
  value       = aws_subnet.private_other_third[*].id
}

output "firewall_subnet_ids" {
  description = "List of IDs of firewall subnets"
  value       = aws_subnet.firewall[*].id
}

output "transit_gateway_subnet_ids" {
  description = "List of IDs of transit gateway subnets"
  value       = aws_subnet.transit_gateway[*].id
}

output "nat_gateway_ids" {
  description = "ID of the NAT gateway (null if NAT is disabled)"
  value       = var.enable_nat_gateway ? aws_nat_gateway.this[0].id : null
}

output "nat_gateway_public_ips" {
  description = "List of public IPs of NAT gateways"
  value       = aws_eip.nat[*].public_ip
}

output "transit_gateway_attachment_id" {
  description = "The ID of the Transit Gateway VPC attachment"
  value = var.enable_tgw_attachment ? aws_ec2_transit_gateway_vpc_attachment.this[0].id : null
}