output "bucket_id" {
  description = "Bucket name"
  value       = one(aws_s3_bucket.this[*].id)
}

output "bucket_arn" {
  description = "Bucket ARN"
  value       = one(aws_s3_bucket.this[*].arn)
}

output "bucket_domain_name" {
  description = "Bucket domain name"
  value       = one(aws_s3_bucket.this[*].bucket_domain_name)
}

output "bucket_regional_domain_name" {
  description = "Regional bucket domain name"
  value       = one(aws_s3_bucket.this[*].bucket_regional_domain_name)
}

output "bucket_hosted_zone_id" {
  description = "Route53 hosted zone ID of the bucket region, used for S3 website alias records"
  value       = one(aws_s3_bucket.this[*].hosted_zone_id)
}

output "bucket_region" {
  description = "Region the bucket lives in"
  value       = one(aws_s3_bucket.this[*].region)
}

output "website_endpoint" {
  description = "Static website endpoint, null when the website feature is off"
  value       = one(aws_s3_bucket_website_configuration.this[*].website_endpoint)
}

output "bucket_policy_json" {
  description = "Bucket policy that was applied, null when no policy is attached"
  value       = one(aws_s3_bucket_policy.this[*].policy)
}
