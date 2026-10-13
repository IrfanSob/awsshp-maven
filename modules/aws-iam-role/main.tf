locals {
  # Build a trust policy from structured inputs unless a full JSON policy is supplied.
  build_trust = var.assume_role_policy == null

  trust_statements = concat(
    length(var.trusted_services) > 0 ? [{
      Effect    = "Allow"
      Principal = { Service = var.trusted_services }
      Action    = var.assume_role_actions
    }] : [],
    length(var.trusted_aws_principals) > 0 ? [{
      Effect    = "Allow"
      Principal = { AWS = var.trusted_aws_principals }
      Action    = var.assume_role_actions
    }] : [],
  )

  assume_role_policy = local.build_trust ? jsonencode({
    Version   = "2012-10-17"
    Statement = local.trust_statements
  }) : var.assume_role_policy
}

resource "aws_iam_role" "this" {
  name                  = var.name
  path                  = var.path
  description           = var.description
  assume_role_policy    = local.assume_role_policy
  max_session_duration  = var.max_session_duration
  permissions_boundary  = var.permissions_boundary
  force_detach_policies = var.force_detach_policies

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )

  lifecycle {
    precondition {
      condition     = var.assume_role_policy != null || length(var.trusted_services) > 0 || length(var.trusted_aws_principals) > 0
      error_message = "Provide either assume_role_policy (raw JSON) or at least one of trusted_services / trusted_aws_principals."
    }
  }
}

# Attach AWS-managed or customer-managed policies by ARN.
resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

# Inline policies (name => JSON document).
resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies

  name   = each.key
  role   = aws_iam_role.this.id
  policy = each.value
}

# Optional instance profile (for EC2 / recovery-instance roles).
resource "aws_iam_instance_profile" "this" {
  count = var.create_instance_profile ? 1 : 0

  name = coalesce(var.instance_profile_name, var.name)
  path = var.path
  role = aws_iam_role.this.name

  tags = merge(
    var.tags,
    {
      Name = coalesce(var.instance_profile_name, var.name)
    }
  )
}
