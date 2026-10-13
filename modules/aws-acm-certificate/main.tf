locals {
  certificate_domains = concat([var.domain_name], var.subject_alternative_names)

  # ACM returns one validation option per domain, but a certificate covering both
  # example.com and *.example.com gets the SAME validation record for each, so the
  # pair has to collapse into one Route 53 record.
  #
  # The obvious way to collapse it -- grouping the validation options by
  # resource_record_name -- cannot work: that attribute is unknown until apply, and
  # for_each keys must be known at plan time. So the keys come from the domain list
  # in the configuration instead, and a wildcard is dropped whenever its own apex is
  # also on the certificate. Apply-time values are only ever used as map VALUES.
  validation_domains = toset([
    for domain in local.certificate_domains : domain
    if !(substr(domain, 0, 2) == "*." && contains(local.certificate_domains, substr(domain, 2, -1)))
  ])

  validation_options_by_domain = {
    for option in aws_acm_certificate.this.domain_validation_options :
    option.domain_name => option
  }

  create_records = var.create_route53_records && var.validation_method == "DNS"
}

# Certificate request
resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = var.validation_method
  key_algorithm             = var.key_algorithm

  dynamic "options" {
    for_each = var.certificate_transparency_logging_preference != null ? [1] : []
    content {
      certificate_transparency_logging_preference = var.certificate_transparency_logging_preference
    }
  }

  tags = merge(
    var.tags,
    { "Name" = var.domain_name }
  )

  # Recommended by AWS: lets a replacement certificate be issued before the
  # in-use one is destroyed, so listeners are never left without a certificate.
  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = !var.create_route53_records || var.route53_zone_id != null || length(var.route53_zone_ids) > 0
      error_message = "create_route53_records requires route53_zone_id, or route53_zone_ids covering every domain."
    }
  }
}

# DNS validation records in Route 53
resource "aws_route53_record" "validation" {
  for_each = local.create_records ? local.validation_domains : toset([])

  # Wildcards validate against the apex, so strip the prefix before resolving
  # which hosted zone the record belongs in.
  zone_id = lookup(var.route53_zone_ids, replace(each.value, "*.", ""), var.route53_zone_id)

  name    = local.validation_options_by_domain[each.value].resource_record_name
  type    = local.validation_options_by_domain[each.value].resource_record_type
  records = [local.validation_options_by_domain[each.value].resource_record_value]
  ttl     = var.route53_record_ttl

  # ACM reissues the same record on renewal; overwriting avoids a conflict.
  allow_overwrite = var.route53_allow_overwrite
}

# Blocks until ACM reports the certificate as issued
resource "aws_acm_certificate_validation" "this" {
  count = var.wait_for_validation ? 1 : 0

  certificate_arn = aws_acm_certificate.this.arn

  # Only meaningful for DNS validation with records managed here. Left null when
  # the records live in external DNS, in which case this simply polls until issued.
  validation_record_fqdns = local.create_records ? [for record in aws_route53_record.validation : record.fqdn] : null

  timeouts {
    create = var.validation_timeout
  }
}
