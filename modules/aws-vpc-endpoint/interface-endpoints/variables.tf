variable "name_prefix" {
  description = "Prefix for naming resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where endpoints will be created"
  type        = string
}

variable "create_security_group" {
  description = "Whether to create a shared security group for the interface endpoints"
  type        = bool
  default     = true
}

variable "security_group_name" {
  description = "Security group name if create_security_group is true"
  type        = string
  default     = null
  nullable    = true
}

variable "security_group_description" {
  description = "Security group description for interface endpoints"
  type        = string
  default     = "Security group for interface VPC endpoints"
}

variable "security_group_ids" {
  description = "Existing security group IDs to use when create_security_group is false"
  type        = list(string)
  default     = []
}

variable "security_group_ingress_rules" {
  description = "Ingress rules for created shared security group"
  type = list(object({
    description      = optional(string)
    from_port        = number
    to_port          = number
    protocol         = string
    cidr_blocks      = optional(list(string))
    ipv6_cidr_blocks = optional(list(string))
    prefix_list_ids  = optional(list(string))
    security_groups  = optional(list(string))
    self             = optional(bool)
  }))
  default = [
    {
      description = "HTTPS from VPC"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

variable "security_group_egress_rules" {
  description = "Egress rules for created shared security group"
  type = list(object({
    description      = optional(string)
    from_port        = number
    to_port          = number
    protocol         = string
    cidr_blocks      = optional(list(string))
    ipv6_cidr_blocks = optional(list(string))
    prefix_list_ids  = optional(list(string))
    security_groups  = optional(list(string))
    self             = optional(bool)
  }))
  default = [
    {
      description = "All outbound"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

variable "interface_endpoints" {
  description = "Map of interface VPC endpoints to create"
  type = map(object({
    service_name        = string
    subnet_ids          = list(string)
    security_group_ids  = optional(list(string), [])
    private_dns_enabled = optional(bool, true)
    ip_address_type     = optional(string)
    policy              = optional(string)
    auto_accept         = optional(bool)
    route_table_ids     = optional(list(string))
    dns_options = optional(object({
      dns_record_ip_type                             = optional(string)
      private_dns_only_for_inbound_resolver_endpoint = optional(bool)
    }))
    name = optional(string)
    tags = optional(map(string), {})
  }))
}
variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}