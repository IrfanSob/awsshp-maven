variable "enable_s3_protection" {
  description = "Enable S3 protection"
  type        = bool
  default     = true
}

variable "enable_kubernetes_protection" {
  description = "Enable EKS audit log monitoring"
  type        = bool
  default     = false
}

variable "enable_malware_protection" {
  description = "Enable EC2 malware protection"
  type        = bool
  default     = false
}

variable "enable_kubernetes_runtime_monitoring" {
 description = "Enable EKS runtime monitoring"
 type        = bool
 default     = false
}

variable "enable_kubernetes_addon_management" {
 description = "Enable EKS addon management"
 type        = bool
 default     = false  
}

variable "enable_ebs_malware_protection" {
  description = "Enable EBS malware protection"
  type        = bool
  default     = false
}

variable "enable_rds_login_events" {
  description = "Enable RDS login events monitoring"
  type        = bool
  default     = false
}

variable "enable_lambda_network_logs" {
  description = "Enable Lambda network logs monitoring"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}