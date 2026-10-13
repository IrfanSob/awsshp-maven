variable "vpc_id" {
  description = "VPC ID to enable flow logs"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "flow_log_name" {
  description = "Flow log name"
  type        = string
}

variable "retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 7
}

variable "traffic_type" {
  description = "Type of traffic to capture (ACCEPT | REJECT | ALL)"
  type        = string
  default     = "ALL"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}