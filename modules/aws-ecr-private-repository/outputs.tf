output "repository_names" {
  description = "Map of repository names"
  value = {
    for repo, r in aws_ecr_repository.this :
    repo => r.name
  }
}

output "repository_urls" {
  description = "Map of repository URLs"
  value = {
    for repo, r in aws_ecr_repository.this :
    repo => r.repository_url
  }
}

output "repository_arns" {
  description = "Map of repository ARNs"
  value = {
    for repo, r in aws_ecr_repository.this :
    repo => r.arn
  }
}

output "registry_id" {
  description = "Registry ID (AWS account ID) that holds the repositories"
  value       = try(values(aws_ecr_repository.this)[0].registry_id, null)
}
