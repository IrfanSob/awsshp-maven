variable "vpc_id" {
  description = "VPC ID where the route tables will be created."
  type        = string
}

variable "vpc_name" {
  description = "Base name/prefix for tagging the route tables."
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "public_subnets" {
  description = "List of public subnet IDs to associate to the public route table."
  type        = list(string)
  default     = []
}

variable "private_app_subnets" {
  description = "List of private subnet IDs to associate to the private app route table."
  type        = list(string)
  default     = []
}

variable "private_db_subnets" {
  description = "List of private subnet IDs to associate to the private DB route table."
  type        = list(string)
  default     = []
}

variable "other_private_subnets_first" {
  description = "List of other private subnet IDs to associate to the first other private route table."
  type        = list(string)
  default     = []
}

variable "other_private_subnets_second" {
  description = "List of other private subnet IDs to associate to the second other private route table."
  type        = list(string)
  default     = []
}

variable "other_private_subnets_third" {
  description = "List of other private subnet IDs to associate to the third other private route table."
  type        = list(string)
  default     = []
}

variable "transit_gateway_subnets" {
  description = "List of subnet IDs to associate to the transit-gateway route table."
  type        = list(string)
  default     = []
}

variable "public_route_table_name" {
  description = "Suffix or name part for the public route table tag."
  type        = string
  default     = "Public"
}

variable "private_app_route_table_name" {
  description = "Suffix or name part for the private route table tag."
  type        = string
  default     = "Private-App"
}

variable "private_db_route_table_name" {
  description = "Suffix or name part for the private DB route table tag."
  type        = string
  default     = "Private-DB"
}

variable "other_private_subnets_first_route_table_name" {
  description = "Suffix or name part for the first other private route table tag."
  type        = string
  default     = "Other-Private-First"
}

variable "other_private_subnets_second_route_table_name" {
  description = "Suffix or name part for the second other private route table tag."
  type        = string
  default     = "Other-Private-Second"
}

variable "other_private_subnets_third_route_table_name" {
  description = "Suffix or name part for the third other private route table tag."
  type        = string
  default     = "Other-Private-Third"
}

variable "transit_gateway_route_table_name" {
  description = "Suffix or name part for the transit-gateway route table tag."
  type        = string
  default     = "tgw"
}

variable "enable_public_route" {
  description = "Whether to create the 0.0.0.0/0 route in the public route table via the Internet Gateway."
  type        = bool
  default     = false
}

variable "internet_gateway_id" {
  description = "Internet Gateway ID for the public route table default route."
  type        = string
  default     = null
  validation {
    condition     = var.internet_gateway_id != "" || var.internet_gateway_id == null
    error_message = "internet_gateway_id must be a non-empty string or null."
  }
}

variable "enable_nat_route" {
  description = "Whether to create the 0.0.0.0/0 route in the private route table via the NAT Gateway."
  type        = bool
  default     = false
}

# NOTE: Despite the plural name, this should be a SINGLE NAT Gateway ID.
variable "nat_gateway_ids" {
  description = "NAT Gateway ID for the private route table default route (single ID expected)."
  type        = string
  default     = ""
}

variable "transit_gateway_id" {
  description = "Transit Gateway ID."
  type        = string
  default     = ""
}

variable "prefix_list_id" {
  description = "Managed Prefix List ID (destination)."
  type        = string
  default     = ""
}

variable "create_pl_route" {
  description = "Whether to create the route to TGW using the prefix list."
  type        = bool
  default     = false
}
