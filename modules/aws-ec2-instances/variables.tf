variable "instances" {
  description = "Map of EC2 instances"
  type = map(object({
    ami_id             = string
    instance_type      = string
    subnet_id          = string
    security_group_ids = list(string)
    key_name           = optional(string)

    create_key_pair = optional(bool, false)
    key_pair_name   = optional(string)
    key_algorithm   = optional(string, "RSA")
    rsa_bits        = optional(number, 4096)

    iam_instance_profile = optional(string)

    # Left null on purpose. This attribute is Optional+Computed and ForceNew:
    # attaching an Elastic IP makes AWS report it as true, so pinning it to
    # false puts the instance in a permanent replace loop. Leave it unset unless
    # the instance has no Elastic IP and you specifically need to override the
    # subnet's map_public_ip_on_launch setting.
    associate_public_ip_address = optional(bool)

    availability_zone       = optional(string)
    user_data               = optional(string)
    user_data_base64        = optional(string)
    ebs_optimized           = optional(bool)
    monitoring              = optional(bool, false)
    disable_api_termination = optional(bool, false)
    source_dest_check       = optional(bool, true)

    root_block_device = optional(object({
      volume_type           = optional(string, "gp3")
      volume_size           = optional(number, 20)
      encrypted             = optional(bool, true)
      kms_key_id            = optional(string)
      delete_on_termination = optional(bool, true)
      iops                  = optional(number)
      throughput            = optional(number)
    }))

    metadata_options = optional(object({
      http_endpoint               = optional(string, "enabled")
      http_tokens                 = optional(string, "required")
      http_put_response_hop_limit = optional(number, 2)
      instance_metadata_tags      = optional(string, "enabled")
    }))

    ebs_volumes = optional(list(object({
      device_name = string
      size        = number
      type        = optional(string, "gp3")
      encrypted   = optional(bool, true)
      kms_key_id  = optional(string)
      iops        = optional(number)
      throughput  = optional(number)
      tags        = optional(map(string), {})
    })))

    tags = optional(map(string))
  }))
}

variable "create_iam_role" {
  description = "Whether to create the IAM role and instance profile. Set to false on additional module calls to reuse an existing instance profile"
  type        = bool
  default     = true
}

variable "existing_iam_instance_profile_name" {
  description = "Name of an existing instance profile to attach when create_iam_role is false"
  type        = string
  default     = null
}

variable "iam_role_name" {
  description = "IAM role name for EC2 instances"
  type        = string
  default     = "ec2-instance-role"
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name for EC2 instances"
  type        = string
  default     = "ec2-instance-profile"
}

variable "iam_role_tags" {
  description = "Additional tags for IAM role"
  type        = map(string)
  default     = {}
}

variable "iam_instance_profile_tags" {
  description = "Additional tags for IAM instance profile"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# Store key to bucket
variable "store_key_in_s3" {
  description = "Store generated SSH key in S3"
  type        = bool
  default     = true
}

variable "ssh_key_bucket" {
  description = "S3 bucket to store generated SSH keys"
  type        = string
  default     = null
}

variable "ssh_key_prefix" {
  description = "Prefix path in S3 bucket"
  type        = string
  default     = "ec2-keys"
}

variable "ssh_key_kms_key_id" {
  description = "KMS key for S3 encryption"
  type        = string
  default     = null
}