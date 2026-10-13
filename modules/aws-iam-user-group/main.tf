locals {
  # Resolve to the created group when this module owns it, so that policy
  # attachments and memberships depend on the group actually existing.
  group_name = var.create_group ? one(aws_iam_group.this[*].name) : var.group_name
}

# IAM Group (optional)
# Note: IAM groups do not support tags, so var.tags is not applied here.
resource "aws_iam_group" "this" {
  count = var.create_group ? 1 : 0

  name = var.group_name
  path = var.group_path
}

# IAM Users
resource "aws_iam_user" "this" {
  for_each = var.users

  name                 = each.key
  path                 = each.value.path
  permissions_boundary = each.value.permissions_boundary
  force_destroy        = each.value.force_destroy

  tags = merge(
    var.tags,
    each.value.tags,
    { "Name" = each.key }
  )
}

# Group membership
# aws_iam_user_group_membership is non-authoritative: it adds these users to the
# group without removing members managed elsewhere. aws_iam_group_membership
# would take over the whole group and clobber existing members.
resource "aws_iam_user_group_membership" "this" {
  for_each = {
    for name, user in var.users : name => user
    if user.add_to_group && var.group_name != null
  }

  user   = aws_iam_user.this[each.key].name
  groups = [local.group_name]
}

# Customer managed policies created by this module
resource "aws_iam_policy" "this" {
  for_each = var.customer_managed_policies

  name        = each.key
  path        = each.value.path
  description = each.value.description
  policy      = each.value.policy

  tags = merge(
    var.tags,
    each.value.tags,
    { "Name" = each.key }
  )
}

# Attach policies created by this module to the group
resource "aws_iam_group_policy_attachment" "customer_managed" {
  for_each = var.customer_managed_policies

  group      = local.group_name
  policy_arn = aws_iam_policy.this[each.key].arn
}

# Attach existing policies by ARN (AWS managed or pre-existing customer managed)
resource "aws_iam_group_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  group      = local.group_name
  policy_arn = each.value
}

# Inline policies on the group (name => JSON document)
resource "aws_iam_group_policy" "inline" {
  for_each = var.inline_policies

  name   = each.key
  group  = local.group_name
  policy = each.value
}
