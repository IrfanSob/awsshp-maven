locals {
  # Use the created customer gateway, or an existing one passed by the caller
  customer_gateway_id = var.create_customer_gateway ? aws_customer_gateway.this[0].id : var.customer_gateway_id

  # Use the created VGW, or an existing one passed by the caller
  vpn_gateway_id = var.create_vpn_gateway ? aws_vpn_gateway.this[0].id : var.vpn_gateway_id
}

# Optional Virtual Private Gateway, created and attached to the given VPC.
resource "aws_vpn_gateway" "this" {
  count = var.create_vpn_gateway ? 1 : 0

  vpc_id            = var.vpn_gateway_vpc_id
  amazon_side_asn   = var.vpn_gateway_amazon_side_asn
  availability_zone = var.vpn_gateway_availability_zone

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-vgw"
    }
  )
}

resource "aws_customer_gateway" "this" {
  count = var.create_customer_gateway ? 1 : 0

  bgp_asn         = var.customer_gateway_bgp_asn
  ip_address      = var.customer_gateway_ip_address
  type            = "ipsec.1"
  device_name     = var.customer_gateway_device_name
  certificate_arn = var.customer_gateway_certificate_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-cgw"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpn_connection" "this" {
  customer_gateway_id = local.customer_gateway_id
  type                = "ipsec.1"

  # Exactly one of these determines the target (VGW or TGW)
  vpn_gateway_id     = local.vpn_gateway_id
  transit_gateway_id = var.transit_gateway_id

  static_routes_only = var.static_routes_only

  # enable_acceleration is only valid together with a Transit Gateway target
  enable_acceleration = var.transit_gateway_id != null ? var.enable_acceleration : null

  local_ipv4_network_cidr  = var.local_ipv4_network_cidr
  remote_ipv4_network_cidr = var.remote_ipv4_network_cidr

  tunnel1_inside_cidr   = var.tunnel1_inside_cidr
  tunnel2_inside_cidr   = var.tunnel2_inside_cidr
  tunnel1_preshared_key = var.tunnel1_preshared_key
  tunnel2_preshared_key = var.tunnel2_preshared_key

  tunnel1_ike_versions = var.tunnel1_ike_versions
  tunnel2_ike_versions = var.tunnel2_ike_versions

  tunnel1_startup_action = var.tunnel1_startup_action
  tunnel2_startup_action = var.tunnel2_startup_action

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )

  lifecycle {
    precondition {
      condition     = (local.vpn_gateway_id != null) != (var.transit_gateway_id != null)
      error_message = "Exactly one target must be set: a VGW (create_vpn_gateway or vpn_gateway_id) or transit_gateway_id."
    }

    precondition {
      condition     = !(var.create_vpn_gateway && var.vpn_gateway_id != null)
      error_message = "Set only one of create_vpn_gateway or vpn_gateway_id, not both."
    }

    precondition {
      condition     = !var.create_vpn_gateway || var.vpn_gateway_vpc_id != null
      error_message = "vpn_gateway_vpc_id must be set when create_vpn_gateway is true."
    }

    precondition {
      condition     = var.create_customer_gateway || var.customer_gateway_id != null
      error_message = "customer_gateway_id must be set when create_customer_gateway is false."
    }
  }
}

# Static routes for the VPN connection.
# Only valid when static_routes_only = true and the target is a Virtual Private Gateway.
# For Transit Gateway targets, manage routing with aws_ec2_transit_gateway_route instead.
resource "aws_vpn_connection_route" "this" {
  for_each = toset(var.static_routes)

  vpn_connection_id      = aws_vpn_connection.this.id
  destination_cidr_block = each.value
}

# Propagate routes into the given route tables. Only valid for a VGW target.
# Keyed by a static name so route table IDs can be resolved at apply time.
resource "aws_vpn_gateway_route_propagation" "this" {
  for_each = var.propagation_route_tables

  vpn_gateway_id = local.vpn_gateway_id
  route_table_id = each.value
}
