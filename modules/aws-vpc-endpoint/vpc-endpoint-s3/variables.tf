variable "vpc_id" {
  description = "The ID of the VPC where the S3 VPC Endpoint will be created."
  type        = string
}

variable "region" {
  description = "AWS region for the S3 service name (e.g., us-east-1)."
  type        = string
}

variable "endpoint_type" {
  description = "The type of VPC endpoint. For S3, must be 'Gateway'."
  type        = string
  default     = "Gateway"
  validation {
    condition     = var.endpoint_type == "Gateway"
    error_message = "Only 'Gateway' endpoint type is valid for S3."
  }
}

variable "route_table_ids" {
  description = "List of Route Table IDs to associate with the S3 Gateway Endpoint."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "endpoint_name" {
  description = "Name tag for the VPC endpoint"
  type        = string
  default     = "S3-Gateway-Endpoint"
}
