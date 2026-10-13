# VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(
    var.tags,
    { "Name" = var.vpc_name })
}

# Internet Gateway (IGW)
resource "aws_internet_gateway" "this" {
  count  = var.enable_igw ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = merge(
    var.tags,
    { "Name" = "${var.vpc_name}-igw" })
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = length(var.public_subnet_azs) > 0 ? var.public_subnet_azs[count.index] : element(var.azs, count.index)
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      "Name" = "${var.vpc_name}-${var.public_subnet_names[count.index]}"
    }
  )
}

# Private App Subnets (For TGW, Workloads)
resource "aws_subnet" "private_app" {
  count = length(var.private_app_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_app_subnets[count.index]
  availability_zone = length(var.private_app_subnet_azs) > 0 ? var.private_app_subnet_azs[count.index] : element(var.azs, count.index)

  tags = merge(
    var.tags,
    {
      "Name" = "${var.vpc_name}-${var.private_app_subnet_names[count.index]}"
    }
  )
}

# Private DB Subnets (For TGW, Workloads)
resource "aws_subnet" "private_db" {
  count = length(var.private_db_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_db_subnets[count.index]
  availability_zone = length(var.private_db_subnet_azs) > 0 ? var.private_db_subnet_azs[count.index] : element(var.azs, count.index)

  tags = merge(
    var.tags,
    {
      "Name" = "${var.vpc_name}-${var.private_db_subnet_names[count.index]}"
    }
  )
}

# Firewall Subnets (Private)
resource "aws_subnet" "firewall" {
  count = length(var.firewall_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.firewall_subnets[count.index]
  availability_zone = length(var.firewall_subnet_azs) > 0 ? var.firewall_subnet_azs[count.index] : element(var.azs, count.index)

  tags = merge(
    var.tags,
    {
      "Name" = "${var.vpc_name}-${var.firewall_subnet_names[count.index]}"
    }
  )
}

# Transit Gateway Subnets (Private)
resource "aws_subnet" "transit_gateway" {
  count = length(var.transit_gateway_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.transit_gateway_subnets[count.index]
  availability_zone = length(var.transit_gateway_subnet_azs) > 0 ? var.transit_gateway_subnet_azs[count.index] : element(var.azs, count.index)

  tags = merge(
    var.tags,
    {
      "Name" = "${var.vpc_name}-${var.transit_gateway_subnet_names[count.index]}"
    }
  )
}

# Private Other - First Subnets (For TGW, Workloads)
resource "aws_subnet" "private_other_first" {
  count = length(var.other_private_subnets_first)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.other_private_subnets_first[count.index]
  availability_zone = length(var.other_private_subnet_first_azs) > 0 ? var.other_private_subnet_first_azs[count.index] : element(var.azs, count.index)

  tags = merge(
    var.tags,
    {
      "Name" = "${var.vpc_name}-${var.other_private_subnet_first_names[count.index]}"
    }
  )
}

# Private Other - Second Subnets (For TGW, Workloads)
resource "aws_subnet" "private_other_second" {
  count = length(var.other_private_subnets_second)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.other_private_subnets_second[count.index]
  availability_zone = length(var.other_private_subnet_second_azs) > 0 ? var.other_private_subnet_second_azs[count.index] : element(var.azs, count.index)

  tags = merge(
    var.tags,
    {
      "Name" = "${var.vpc_name}-${var.other_private_subnet_second_names[count.index]}"
    }
  )
}

# Private Other - Third Subnets (For TGW, Workloads)
resource "aws_subnet" "private_other_third" {
  count = length(var.other_private_subnets_third)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.other_private_subnets_third[count.index]
  availability_zone = length(var.other_private_subnet_third_azs) > 0 ? var.other_private_subnet_third_azs[count.index] : element(var.azs, count.index)

  tags = merge(
    var.tags,
    {
      "Name" = "${var.vpc_name}-${var.other_private_subnet_third_names[count.index]}"
    }
  )
}

# NAT Gateway (Optional)
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"
}

resource "aws_nat_gateway" "this" {
  count         = var.enable_nat_gateway ? 1 : 0
  subnet_id     = aws_subnet.public[0].id
  allocation_id = aws_eip.nat[0].id
  tags          = merge(
    var.tags,
    { "Name" = "${var.vpc_name}-${var.nat_gateway_name}" })
}

# Transit Gateway
# Attach VPC to Transit Gateway
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  count              = var.enable_tgw_attachment && length(local.tgw_attachment_subnets[var.subnet_type_for_tgw_attachment]) > 0 ? 1 : 0
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = aws_vpc.this.id
  subnet_ids         = local.tgw_attachment_subnets[var.subnet_type_for_tgw_attachment]
  appliance_mode_support  = var.appliance_mode_support
  tags               = merge(
    var.tags,
    { "Name" = "${var.vpc_name}-tgw-attachment" })
}

locals {
  tgw_attachment_subnets = {
    "public"          = [for s in aws_subnet.public : s.id]
    "private_app"         = [for s in aws_subnet.private_app : s.id]
    "private_db"         = [for s in aws_subnet.private_db : s.id]
    "firewall"        = [for s in aws_subnet.firewall : s.id]
    "transit_gateway" = var.enable_tgw_attachment ? [for s in aws_subnet.transit_gateway : s.id] : []
    "other_private_first"         = [for s in aws_subnet.private_other_first : s.id]
    "other_private_second"         = [for s in aws_subnet.private_other_second : s.id]
    "other_private_third"         = [for s in aws_subnet.private_other_third : s.id]
  }
}
