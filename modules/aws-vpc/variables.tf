variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "vpc_name" {
  description = "The name of the VPC used for resource naming"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "azs" {
  description = "A list of availability zones in the region (used as fallback when a per-group *_subnet_azs list is not provided)"
  type        = list(string)
}

# Public subnet variables
variable "public_subnets" {
  description = "A list of public subnet CIDR blocks"
  type        = list(string)
  default     = []
}

variable "public_subnet_names" {
  description = "A list of names for public subnets"
  type        = list(string)
  default     = []
}

variable "public_subnet_azs" {
  description = "A list of AZs for public subnets (index-aligned with public_subnets). If empty, falls back to azs by position."
  type        = list(string)
  default     = []
}

# Private App subnet variables
variable "private_app_subnets" {
  description = "A list of private App subnet CIDR blocks"
  type        = list(string)
  default     = []
}

variable "private_app_subnet_names" {
  description = "A list of names for private App subnets"
  type        = list(string)
  default     = []
}

variable "private_app_subnet_azs" {
  description = "A list of AZs for private App subnets (index-aligned with private_app_subnets). If empty, falls back to azs by position."
  type        = list(string)
  default     = []
}

# Private DB subnet variables
variable "private_db_subnets" {
  description = "A list of private DB subnet CIDR blocks"
  type        = list(string)
  default     = []
}

variable "private_db_subnet_names" {
  description = "A list of names for private DB subnets"
  type        = list(string)
  default     = []
}

variable "private_db_subnet_azs" {
  description = "A list of AZs for private DB subnets (index-aligned with private_db_subnets). If empty, falls back to azs by position."
  type        = list(string)
  default     = []
}

# Firewall subnet variables
variable "firewall_subnets" {
  description = "A list of firewall subnet CIDR blocks"
  type        = list(string)
  default     = []
}

variable "firewall_subnet_names" {
  description = "A list of names for firewall subnets"
  type        = list(string)
  default     = []
}

variable "firewall_subnet_azs" {
  description = "A list of AZs for firewall subnets (index-aligned with firewall_subnets). If empty, falls back to azs by position."
  type        = list(string)
  default     = []
}

# Transit Gateway subnet variables
variable "transit_gateway_subnets" {
  description = "A list of transit gateway subnet CIDR blocks"
  type        = list(string)
  default     = []
}

variable "transit_gateway_subnet_names" {
  description = "A list of names for transit gateway subnets"
  type        = list(string)
  default     = []
}

variable "transit_gateway_subnet_azs" {
  description = "A list of AZs for transit gateway subnets (index-aligned with transit_gateway_subnets). If empty, falls back to azs by position."
  type        = list(string)
  default     = []
}

# Private Other - First Subnets (For TGW, Workloads)
variable "other_private_subnets_first" {
  description = "A list of other private subnet CIDR blocks (not App or DB)"
  type        = list(string)
  default     = []
}

variable "other_private_subnet_first_names" {
  description = "A list of names for other private subnets (not App or DB)"
  type        = list(string)
  default     = []
}

variable "other_private_subnet_first_azs" {
  description = "A list of AZs for other private (first) subnets (index-aligned with other_private_subnets_first). If empty, falls back to azs by position."
  type        = list(string)
  default     = []
}

# Private Other - Second Subnets (For TGW, Workloads)
variable "other_private_subnets_second" {
  description = "A list of other private subnet CIDR blocks (not App or DB)"
  type        = list(string)
  default     = []
}

variable "other_private_subnet_second_names" {
  description = "A list of names for other private subnets (not App or DB)"
  type        = list(string)
  default     = []
}

variable "other_private_subnet_second_azs" {
  description = "A list of AZs for other private (second) subnets (index-aligned with other_private_subnets_second). If empty, falls back to azs by position."
  type        = list(string)
  default     = []
}

# Private Other - Third Subnets (For TGW, Workloads)
variable "other_private_subnets_third" {
  description = "A list of other private subnet CIDR blocks (not App or DB)"
  type        = list(string)
  default     = []
}

variable "other_private_subnet_third_names" {
  description = "A list of names for other private subnets (not App or DB)"
  type        = list(string)
  default     = []
}

variable "other_private_subnet_third_azs" {
  description = "A list of AZs for other private (third) subnets (index-aligned with other_private_subnets_third). If empty, falls back to azs by position."
  type        = list(string)
  default     = []
}

# Internet Gateway variables
variable "enable_igw" {
  description = "Whether to create an internet gateway"
  type        = bool
  default     = false
}

# NAT Gateway variables
variable "enable_nat_gateway" {
  description = "Whether to create NAT gateways"
  type        = bool
  default     = false
}

variable "nat_gateway_name" {
  description = "A list of names for NAT gateways"
  type        = string
  default     = ""
}

# Transit Gateway variables
variable "transit_gateway_id" {
  description = "The ID of the transit gateway to attach to"
  type        = string
  default     = ""
}

variable "enable_tgw_attachment" {
  description = "Whether to create a TGW VPC attachment at all"
  type        = bool
  default     = false
}

variable "subnet_type_for_tgw_attachment" {
  description = "Type of subnets to attach (public, private, firewall, transit_gateway)"
  type        = string
  default     = "transit_gateway"  # Default to dedicated TGW subnets
  validation {
    condition     = contains(["public", "private", "firewall", "transit_gateway"], var.subnet_type_for_tgw_attachment)
    error_message = "Must be one of: public, private, firewall, transit_gateway."
  }
}

variable "appliance_mode_support" {
  description = "Appliance mode support for TGW Attachment. Valid values: enable or disable."
  type        = string
  default     = "disable"
  validation {
    condition     = contains(["enable", "disable"], var.appliance_mode_support)
    error_message = "appliance_mode_support must be either 'enable' or 'disable'."
  }
}
