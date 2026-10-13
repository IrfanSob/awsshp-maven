variable "name" {
  description = "Name of the security group"
  type        = string
}

variable "description" {
  description = "Description of the security group"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID where the security group will be created"
  type        = string
}

variable "inbound_rules" {
  description = "List of inbound security group rules. Set self = true for a rule whose source is this security group"
  type = list(object({
    port                = number
    protocol            = string
    description         = optional(string)
    cidr_blocks         = optional(list(string), [])
    ipv6_cidr_blocks    = optional(list(string), [])
    source_security_group_id = optional(string)
    self                = optional(bool, false)
  }))
}

variable "outbound_rules" {
  description = "List of outbound security group rules"
  type = list(object({
    port                = number
    protocol            = string
    description         = optional(string)
    cidr_blocks         = optional(list(string), [])
    ipv6_cidr_blocks    = optional(list(string), [])
    source_security_group_id = optional(string)
  }))
}

variable "tags" {
  description = "Tags to assign to security groups"
  type        = map(string)
  default     = {}
}