# --- Certificate ------------------------------------------------------------------

variable "domain_name" {
  description = "Primary domain name for the certificate, e.g. dev-erp.uniramagroup.co.id or *.unirama.id"
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional domain names the certificate should cover"
  type        = list(string)
  default     = []
}

variable "validation_method" {
  description = "How ACM verifies domain ownership. DNS is recommended because it renews automatically"
  type        = string
  default     = "DNS"

  validation {
    condition     = contains(["DNS", "EMAIL"], var.validation_method)
    error_message = "validation_method must be either DNS or EMAIL."
  }
}

variable "key_algorithm" {
  description = "Key algorithm for the certificate, e.g. RSA_2048 or EC_prime256v1. Uses the ACM default when null"
  type        = string
  default     = null
}

variable "certificate_transparency_logging_preference" {
  description = "Whether certificate details are written to public Certificate Transparency logs. ENABLED or DISABLED"
  type        = string
  default     = null

  validation {
    condition     = contains(["ENABLED", "DISABLED"], coalesce(var.certificate_transparency_logging_preference, "ENABLED"))
    error_message = "certificate_transparency_logging_preference must be either ENABLED or DISABLED."
  }
}

# --- Route 53 validation ------------------------------------------------------------

variable "create_route53_records" {
  description = "Whether to create the DNS validation records in Route 53. Set to false when the domain is hosted on external DNS, then create the records shown in the domain_validation_options output by hand"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Hosted zone ID used for every validation record not matched by route53_zone_ids"
  type        = string
  default     = null
}

variable "route53_zone_ids" {
  description = "Per domain hosted zone IDs, keyed by apex domain, for certificates spanning several zones. A wildcard such as *.unirama.id is matched by the key unirama.id"
  type        = map(string)
  default     = {}
}

variable "route53_record_ttl" {
  description = "TTL in seconds for the validation records"
  type        = number
  default     = 60
}

variable "route53_allow_overwrite" {
  description = "Allow the validation records to overwrite an existing record of the same name. Useful because ACM reissues identical records on renewal"
  type        = bool
  default     = true
}

# --- Validation waiting -------------------------------------------------------------

variable "wait_for_validation" {
  description = "Whether to block the apply until ACM reports the certificate as issued. Leave false when validation records are created outside Terraform and issuance may take a while"
  type        = bool
  default     = false
}

variable "validation_timeout" {
  description = "How long to wait for the certificate to be issued before failing"
  type        = string
  default     = "45m"
}

# --- Tags ---------------------------------------------------------------------------

variable "tags" {
  description = "A map of tags to apply to the certificate"
  type        = map(string)
  default     = {}
}
