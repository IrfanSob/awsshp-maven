# Create Security Group
resource "aws_security_group" "this" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}

# Create Multiple Inbound Rules
# Keyed by index so several rules may share the same port/protocol
# (e.g. one DB port opened to more than one source security group).
resource "aws_security_group_rule" "inbound" {
  for_each = { for idx, rule in var.inbound_rules : "${idx}-${rule.port}-${rule.protocol}" => rule }

  type              = "ingress"
  from_port         = each.value.port
  to_port           = each.value.port
  protocol          = each.value.protocol
  security_group_id = aws_security_group.this.id
  description       = each.value.description

  # An empty list still counts as "set" to the provider and would collide with
  # source_security_group_id, so unused sources must be null rather than [].
  cidr_blocks              = length(each.value.cidr_blocks) > 0 ? each.value.cidr_blocks : null
  ipv6_cidr_blocks         = length(each.value.ipv6_cidr_blocks) > 0 ? each.value.ipv6_cidr_blocks : null
  source_security_group_id = each.value.source_security_group_id

  # null rather than false when unset, so existing rules see no diff.
  self = each.value.self ? true : null
}

# Create Multiple Outbound Rules
resource "aws_security_group_rule" "outbound" {
  for_each = { for idx, rule in var.outbound_rules : "${idx}-${rule.port}-${rule.protocol}" => rule }

  type              = "egress"
  from_port         = each.value.port
  to_port           = each.value.port
  protocol          = each.value.protocol
  security_group_id = aws_security_group.this.id
  description       = each.value.description

  cidr_blocks              = length(each.value.cidr_blocks) > 0 ? each.value.cidr_blocks : null
  ipv6_cidr_blocks         = length(each.value.ipv6_cidr_blocks) > 0 ? each.value.ipv6_cidr_blocks : null
  source_security_group_id = each.value.source_security_group_id
}