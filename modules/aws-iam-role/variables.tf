variable "name" {
  description = "Name of the IAM role"
  type        = string
}

variable "path" {
  description = "Path under which to create the role and instance profile"
  type        = string
  default     = "/"
}

variable "description" {
  description = "Description of the IAM role"
  type        = string
  default     = null
}

# --- Trust policy -------------------------------------------------------------

variable "assume_role_policy" {
  description = "Full trust policy as a JSON string. If set, the structured trust inputs below are ignored"
  type        = string
  default     = null
}

variable "trusted_services" {
  description = "AWS service principals allowed to assume the role, e.g. [\"ec2.amazonaws.com\", \"drs.amazonaws.com\"]"
  type        = list(string)
  default     = []
}

variable "trusted_aws_principals" {
  description = "AWS account IDs or IAM ARNs allowed to assume the role"
  type        = list(string)
  default     = []
}

variable "assume_role_actions" {
  description = "STS actions allowed in the trust policy"
  type        = list(string)
  default     = ["sts:AssumeRole"]
}

variable "max_session_duration" {
  description = "Maximum session duration (in seconds) for the role"
  type        = number
  default     = 3600
}

variable "permissions_boundary" {
  description = "ARN of the policy used as the permissions boundary for the role"
  type        = string
  default     = null
}

variable "force_detach_policies" {
  description = "Whether to force detaching any policies the role has before destroying it"
  type        = bool
  default     = false
}

# --- Policies -----------------------------------------------------------------

variable "managed_policy_arns" {
  description = "List of managed policy ARNs (AWS-managed or customer-managed) to attach to the role"
  type        = list(string)
  default     = []
}

variable "inline_policies" {
  description = "Map of inline policies to attach, keyed by policy name with a JSON document value"
  type        = map(string)
  default     = {}
}

# --- Instance profile ---------------------------------------------------------

variable "create_instance_profile" {
  description = "Whether to create an instance profile for this role"
  type        = bool
  default     = false
}

variable "instance_profile_name" {
  description = "Name of the instance profile. Defaults to the role name"
  type        = string
  default     = null
}

# --- Tags ---------------------------------------------------------------------

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
