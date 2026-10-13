output "id" {
  description = "The ID of the VPC endpoint."
  value       = aws_vpc_endpoint.s3_gateway.id
}

output "arn" {
  description = "The ARN of the VPC endpoint."
  value       = aws_vpc_endpoint.s3_gateway.arn
}

output "state" {
  description = "The state of the VPC endpoint."
  value       = aws_vpc_endpoint.s3_gateway.state
}

output "route_table_ids" {
  description = "List of Route Table IDs associated with this endpoint."
  value       = aws_vpc_endpoint.s3_gateway.route_table_ids
}

output "service_name" {
  description = "The service name used for the S3 endpoint."
  value       = aws_vpc_endpoint.s3_gateway.service_name
}