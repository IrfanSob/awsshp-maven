# --- Group ---------------------------------------------------------------------

variable "create_group" {
  description = "Whether to create the IAM group. Set to false to attach users and policies to a group that already exists"
  type        = bool
  default     = true
}

variable "group_name" {
  description = "Name of the IAM group to create, or of the existing group to use when create_group is false. Leave null to manage users only"
  type        = string
  default     = null

  validation {
    condition     = !var.create_group || var.group_name != null
    error_message = "group_name is required when create_group is true."
  }
}

variable "group_path" {
  description = "Path under which to create the IAM group"
  type        = string
  default     = "/"
}

# --- Users ---------------------------------------------------------------------

variable "users" {
  description = "IAM users to create, keyed by user name"
  type = map(object({
    path                 = optional(string, "/")
    permissions_boundary = optional(string)
    force_destroy        = optional(bool, false)
    add_to_group         = optional(bool, true)
    tags                 = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, user in var.users :
      !user.add_to_group || var.group_name != null
    ])
    error_message = "Users with add_to_group enabled require group_name to be set."
  }
}

# --- Policies ------------------------------------------------------------------

variable "managed_policy_arns" {
  description = "ARNs of existing policies to attach to the group. Accepts both AWS managed and customer managed policy ARNs"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.managed_policy_arns) == 0 || var.group_name != null
    error_message = "managed_policy_arns requires group_name to be set."
  }
}

variable "customer_managed_policies" {
  description = "Customer managed policies to create and attach to the group, keyed by policy name. Use managed_policy_arns instead to attach a customer managed policy that already exists"
  type = map(object({
    policy      = string
    description = optional(string)
    path        = optional(string, "/")
    tags        = optional(map(string), {})
  }))
  default = {}

  validation {
    condition     = length(var.customer_managed_policies) == 0 || var.group_name != null
    error_message = "customer_managed_policies requires group_name to be set."
  }
}

variable "inline_policies" {
  description = "Inline policies to embed in the group, keyed by policy name with a JSON document value"
  type        = map(string)
  default     = {}

  validation {
    condition     = length(var.inline_policies) == 0 || var.group_name != null
    error_message = "inline_policies requires group_name to be set."
  }
}

# --- Tags ----------------------------------------------------------------------

variable "tags" {
  description = "A map of tags to apply to taggable resources (IAM users and created policies)"
  type        = map(string)
  default     = {}
}
