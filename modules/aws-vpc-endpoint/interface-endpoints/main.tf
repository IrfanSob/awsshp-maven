resource "aws_security_group" "this" {
  count       = var.create_security_group ? 1 : 0
  name        = var.security_group_name != null ? var.security_group_name : "${var.name_prefix}-vpce-sg"
  description = var.security_group_description
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.security_group_ingress_rules
    content {
      description      = try(ingress.value.description, null)
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      protocol         = ingress.value.protocol
      cidr_blocks      = try(ingress.value.cidr_blocks, null)
      ipv6_cidr_blocks = try(ingress.value.ipv6_cidr_blocks, null)
      prefix_list_ids  = try(ingress.value.prefix_list_ids, null)
      security_groups  = try(ingress.value.security_groups, null)
      self             = try(ingress.value.self, null)
    }
  }

  dynamic "egress" {
    for_each = var.security_group_egress_rules
    content {
      description      = try(egress.value.description, null)
      from_port        = egress.value.from_port
      to_port          = egress.value.to_port
      protocol         = egress.value.protocol
      cidr_blocks      = try(egress.value.cidr_blocks, null)
      ipv6_cidr_blocks = try(egress.value.ipv6_cidr_blocks, null)
      prefix_list_ids  = try(egress.value.prefix_list_ids, null)
      security_groups  = try(egress.value.security_groups, null)
      self             = try(egress.value.self, null)
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.security_group_name != null ? var.security_group_name : "${var.name_prefix}-vpce-sg"
    }
  )
}

resource "aws_vpc_endpoint" "this" {
  for_each = var.interface_endpoints

  vpc_id              = var.vpc_id
  service_name        = each.value.service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = each.value.subnet_ids
  security_group_ids  = length(try(each.value.security_group_ids, [])) > 0 ? each.value.security_group_ids : (
    var.create_security_group ? [aws_security_group.this[0].id] : var.security_group_ids
  )
  private_dns_enabled = try(each.value.private_dns_enabled, true)

  ip_address_type         = try(each.value.ip_address_type, null)
  policy                  = try(each.value.policy, null)
  auto_accept             = try(each.value.auto_accept, null)
  route_table_ids         = try(each.value.route_table_ids, null)

  dynamic "dns_options" {
    for_each = try(each.value.dns_options, null) != null ? [each.value.dns_options] : []
    content {
      dns_record_ip_type                             = try(dns_options.value.dns_record_ip_type, null)
      private_dns_only_for_inbound_resolver_endpoint = try(dns_options.value.private_dns_only_for_inbound_resolver_endpoint, null)
    }
  }

  tags = merge(
    var.tags,
    try(each.value.tags, {}),
    {
      Name = try(each.value.name, "${var.name_prefix}-${each.key}")
    }
  )
}