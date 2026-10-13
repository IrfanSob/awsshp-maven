output "certificate_arn" {
  description = "ARN of the certificate. When wait_for_validation is true this resolves only after ACM has issued it, so consumers cannot attach an unissued certificate"
  value       = var.wait_for_validation ? one(aws_acm_certificate_validation.this[*].certificate_arn) : aws_acm_certificate.this.arn
}

output "certificate_id" {
  description = "ID of the certificate"
  value       = aws_acm_certificate.this.id
}

output "domain_name" {
  description = "Primary domain name on the certificate"
  value       = aws_acm_certificate.this.domain_name
}

output "subject_alternative_names" {
  description = "Additional domain names covered by the certificate"
  value       = aws_acm_certificate.this.subject_alternative_names
}

output "status" {
  description = "Current status of the certificate, for example PENDING_VALIDATION or ISSUED"
  value       = aws_acm_certificate.this.status
}

output "domain_validation_options" {
  description = "Validation records ACM expects. Use this to create the records by hand when the domain is on external DNS"
  value = {
    for domain in local.validation_domains :
    domain => {
      record_name  = local.validation_options_by_domain[domain].resource_record_name
      record_type  = local.validation_options_by_domain[domain].resource_record_type
      record_value = local.validation_options_by_domain[domain].resource_record_value
    }
  }
}

output "validation_record_fqdns" {
  description = "FQDNs of the validation records created in Route 53"
  value       = [for record in aws_route53_record.validation : record.fqdn]
}

output "not_after" {
  description = "Expiry time of the certificate"
  value       = aws_acm_certificate.this.not_after
}
