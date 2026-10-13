resource "aws_ecr_repository" "this" {
  for_each = toset(var.repositories)

  name                 = each.value
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.encryption_type == "KMS" ? var.kms_key_arn : null
  }

  tags = merge(
    var.tags,
    {
      Name = each.value
    }
  )
}

# Lifecycle Policy (toggle: create_lifecycle_policy)
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = var.create_lifecycle_policy ? toset(var.repositories) : toset([])

  repository = aws_ecr_repository.this[each.value].name
  policy = coalesce(var.lifecycle_policy_json, jsonencode({
    rules = concat(
      var.untagged_image_expiry_days != null ? [
        {
          rulePriority = 1
          description  = "Expire untagged images after ${var.untagged_image_expiry_days} days"
          selection = {
            tagStatus   = "untagged"
            countType   = "sinceImagePushed"
            countUnit   = "days"
            countNumber = var.untagged_image_expiry_days
          }
          action = { type = "expire" }
        }
      ] : [],
      [
        {
          rulePriority = 100
          description  = "Keep the last ${var.max_image_count} images"
          selection = {
            tagStatus   = "any"
            countType   = "imageCountMoreThan"
            countNumber = var.max_image_count
          }
          action = { type = "expire" }
        }
      ]
    )
  }))
}

# Repository Policy (toggle: repository_policy_json)
resource "aws_ecr_repository_policy" "this" {
  for_each = var.repository_policy_json != null ? toset(var.repositories) : toset([])

  repository = aws_ecr_repository.this[each.value].name
  policy     = var.repository_policy_json
}
