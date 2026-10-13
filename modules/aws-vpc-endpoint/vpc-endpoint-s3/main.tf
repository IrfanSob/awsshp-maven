resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = var.endpoint_type

  # Associate to route tables (can be empty; AWS allows creating endpoint with no associations initially)
  route_table_ids = var.route_table_ids

  tags = merge(
    var.tags,
    {
      Name = var.endpoint_name
    }
  )

  lifecycle {
    # Safe to toggle route table associations without replacement
    ignore_changes = [
      route_table_ids
    ]
  }
}