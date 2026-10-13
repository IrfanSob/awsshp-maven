#Public Route Table
resource "aws_route_table" "public" {
  count  = length(var.public_subnets) > 0 ? 1 : 0
  vpc_id = var.vpc_id  # Use VPC ID from variable
  tags   = merge(
    var.tags,
    { "Name" = "${var.vpc_name}-${var.public_route_table_name}" }
  )
}

resource "aws_route_table_association" "public_association" {
  for_each       = { for idx, subnet_id in var.public_subnets : idx => subnet_id }
  subnet_id      = each.value
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route" "public_route" {
  count                  = var.enable_public_route && length(var.public_subnets) > 0 ? 1 : 0
  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.internet_gateway_id
}

#Private App Route Table
resource "aws_route_table" "private_app" {
  count  = length(var.private_app_subnets) > 0 ? 1 : 0
  vpc_id = var.vpc_id  # Use VPC ID from variable
  tags   = merge(
    var.tags,
    { "Name" = "${var.vpc_name}-${var.private_app_route_table_name}" }
  )
}

resource "aws_route_table_association" "private_app_association" {
  for_each       = { for idx, subnet_id in var.private_app_subnets : idx => subnet_id }
  subnet_id      = each.value
  route_table_id = aws_route_table.private_app[0].id
}

resource "aws_route" "private_app_nat_route" {
  count                  = var.enable_nat_route && length(var.public_subnets) > 0 && length(var.private_app_subnets) > 0 ? 1 : 0
  route_table_id         = aws_route_table.private_app[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.nat_gateway_ids
}

resource "aws_route" "private_app_pl_to_tgw" {
  count                      = var.create_pl_route && length(var.private_app_subnets) > 0 ? 1 : 0
  route_table_id             = aws_route_table.private_app[0].id
  destination_prefix_list_id = var.prefix_list_id
  transit_gateway_id         = var.transit_gateway_id
}

#Private DB Route Table
resource "aws_route_table" "private_db" {
  count  = length(var.private_db_subnets) > 0 ? 1 : 0
  vpc_id = var.vpc_id  # Use VPC ID from variable
  tags   = merge(
    var.tags,
    { "Name" = "${var.vpc_name}-${var.private_db_route_table_name}" }
  )
}

resource "aws_route_table_association" "private_db_association" {
  for_each       = { for idx, subnet_id in var.private_db_subnets : idx => subnet_id }
  subnet_id      = each.value
  route_table_id = aws_route_table.private_db[0].id
}

resource "aws_route" "private_db_nat_route" {
  count                  = var.enable_nat_route && length(var.public_subnets) > 0 && length(var.private_db_subnets) > 0 ? 1 : 0
  route_table_id         = aws_route_table.private_db[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.nat_gateway_ids
}

resource "aws_route" "private_db_pl_to_tgw" {
  count                      = var.create_pl_route && length(var.private_db_subnets) > 0 ? 1 : 0
  route_table_id             = aws_route_table.private_db[0].id
  destination_prefix_list_id = var.prefix_list_id
  transit_gateway_id         = var.transit_gateway_id
}

# Transit Gateway Route Table
resource "aws_route_table" "transit_gateway" {
  count  = length(var.transit_gateway_subnets) > 0 ? 1 : 0
  vpc_id = var.vpc_id
  tags   = merge(
    var.tags,
    { "Name" = "${var.vpc_name}-transit_gateway-rt" }
  )
}

resource "aws_route_table_association" "transit_gateway_association" {
  for_each       = { for idx, subnet_id in var.transit_gateway_subnets : idx => subnet_id }
  subnet_id      = each.value
  route_table_id = aws_route_table.transit_gateway[0].id
}

#Private Other Route Table - First
resource "aws_route_table" "other_private_subnets_first" {
  count  = length(var.other_private_subnets_first) > 0 ? 1 : 0
  vpc_id = var.vpc_id  # Use VPC ID from variable
  tags   = merge(
    var.tags,
    { "Name" = "${var.vpc_name}-${var.other_private_subnets_first_route_table_name}" }
  )
}

resource "aws_route_table_association" "other_private_subnets_first_association" {
  for_each       = { for idx, subnet_id in var.other_private_subnets_first : idx => subnet_id }
  subnet_id      = each.value
  route_table_id = aws_route_table.other_private_subnets_first[0].id
}

resource "aws_route" "other_private_subnets_first_nat_route" {
  count                  = var.enable_nat_route && length(var.public_subnets) > 0 && length(var.other_private_subnets_first) > 0 ? 1 : 0
  route_table_id         = aws_route_table.other_private_subnets_first[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.nat_gateway_ids
}

resource "aws_route" "other_private_subnets_first_pl_to_tgw" {
  count                      = var.create_pl_route && length(var.other_private_subnets_first) > 0 ? 1 : 0
  route_table_id             = aws_route_table.other_private_subnets_first[0].id
  destination_prefix_list_id = var.prefix_list_id
  transit_gateway_id         = var.transit_gateway_id
}

#Private Other Route Table - Second
resource "aws_route_table" "other_private_subnets_second" {
  count  = length(var.other_private_subnets_second) > 0 ? 1 : 0
  vpc_id = var.vpc_id  # Use VPC ID from variable
  tags   = merge(
    var.tags,
    { "Name" = "${var.vpc_name}-${var.other_private_subnets_second_route_table_name}" }
  )
}

resource "aws_route_table_association" "other_private_subnets_second_association" {
  for_each       = { for idx, subnet_id in var.other_private_subnets_second : idx => subnet_id }
  subnet_id      = each.value
  route_table_id = aws_route_table.other_private_subnets_second[0].id
}

resource "aws_route" "other_private_subnets_second_nat_route" {
  count                  = var.enable_nat_route && length(var.public_subnets) > 0 && length(var.other_private_subnets_second) > 0 ? 1 : 0
  route_table_id         = aws_route_table.other_private_subnets_second[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.nat_gateway_ids
}

resource "aws_route" "other_private_subnets_second_pl_to_tgw" {
  count                      = var.create_pl_route && length(var.other_private_subnets_second) > 0 ? 1 : 0
  route_table_id             = aws_route_table.other_private_subnets_second[0].id
  destination_prefix_list_id = var.prefix_list_id
  transit_gateway_id         = var.transit_gateway_id
}

#Private Other Route Table - Third
resource "aws_route_table" "other_private_subnets_third" {
  count  = length(var.other_private_subnets_third) > 0 ? 1 : 0
  vpc_id = var.vpc_id  # Use VPC ID from variable
  tags   = merge(
    var.tags,
    { "Name" = "${var.vpc_name}-${var.other_private_subnets_third_route_table_name}" }
  )
}

resource "aws_route_table_association" "other_private_subnets_third_association" {
  for_each       = { for idx, subnet_id in var.other_private_subnets_third : idx => subnet_id }
  subnet_id      = each.value
  route_table_id = aws_route_table.other_private_subnets_third[0].id
}

resource "aws_route" "other_private_subnets_third_nat_route" {
  count                  = var.enable_nat_route && length(var.public_subnets) > 0 && length(var.other_private_subnets_third) > 0 ? 1 : 0
  route_table_id         = aws_route_table.other_private_subnets_third[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.nat_gateway_ids
}

resource "aws_route" "other_private_subnets_third_pl_to_tgw" {
  count                      = var.create_pl_route && length(var.other_private_subnets_third) > 0 ? 1 : 0
  route_table_id             = aws_route_table.other_private_subnets_third[0].id
  destination_prefix_list_id = var.prefix_list_id
  transit_gateway_id         = var.transit_gateway_id
}
