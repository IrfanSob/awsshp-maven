# --- General -------------------------------------------------------------------

variable "create_project" {
  description = "Whether to create the project and every resource in this module"
  type        = bool
  default     = true
}

variable "name" {
  description = "Project name, also the base for generated resource names"
  type        = string
}

variable "description" {
  description = "Project description"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to every taggable resource in this module"
  type        = map(string)
  default     = {}
}

variable "build_timeout" {
  description = "Build timeout in minutes (5-2160)"
  type        = number
  default     = 60
}

variable "queued_timeout" {
  description = "Queue timeout in minutes (5-480)"
  type        = number
  default     = null
}

variable "concurrent_build_limit" {
  description = "Maximum concurrent builds. Null leaves it unlimited"
  type        = number
  default     = null
}

variable "auto_retry_limit" {
  description = "Automatic retries after a failed build"
  type        = number
  default     = null
}

variable "badge_enabled" {
  description = "Generate a public build badge URL"
  type        = bool
  default     = false
}

variable "project_visibility" {
  description = "PUBLIC_READ or PRIVATE"
  type        = string
  default     = "PRIVATE"
}

variable "resource_access_role" {
  description = "Role that lets public build viewers read logs and artifacts (PUBLIC_READ projects)"
  type        = string
  default     = null
}

variable "encryption_key" {
  description = "KMS key ARN for build output artifacts. Null uses aws/s3"
  type        = string
  default     = null
}

variable "source_version" {
  description = "Default source version (branch, commit, or S3 object version)"
  type        = string
  default     = null
}

# --- Source --------------------------------------------------------------------

variable "source_config" {
  description = "Primary source. type is NO_SOURCE, S3, CODEPIPELINE, CODECOMMIT, GITHUB, GITHUB_ENTERPRISE, GITLAB, GITLAB_SELF_MANAGED or BITBUCKET. GitLab sources need CodeConnections, which some Regions (e.g. ap-southeast-3) do not offer; use S3 or NO_SOURCE there. NO_SOURCE requires buildspec"
  type = object({
    type                = string
    location            = optional(string)
    buildspec           = optional(string)
    git_clone_depth     = optional(number)
    insecure_ssl        = optional(bool)
    report_build_status = optional(bool)
    fetch_submodules    = optional(bool)
    auth = optional(object({
      type     = string
      resource = string
    }))
    build_status_config = optional(object({
      context    = optional(string)
      target_url = optional(string)
    }))
  })
  default = {
    type = "NO_SOURCE"
  }
}

variable "secondary_sources" {
  description = "Secondary sources, each with a unique source_identifier"
  type = list(object({
    source_identifier   = string
    type                = string
    location            = optional(string)
    buildspec           = optional(string)
    git_clone_depth     = optional(number)
    insecure_ssl        = optional(bool)
    report_build_status = optional(bool)
    fetch_submodules    = optional(bool)
    auth = optional(object({
      type     = string
      resource = string
    }))
    build_status_config = optional(object({
      context    = optional(string)
      target_url = optional(string)
    }))
  }))
  default = []
}

variable "secondary_source_versions" {
  description = "Map of secondary source identifiers to source versions"
  type        = map(string)
  default     = {}
}

# --- Artifacts -----------------------------------------------------------------

variable "artifacts" {
  description = "Primary artifacts. type is NO_ARTIFACTS, S3 or CODEPIPELINE"
  type = object({
    type                   = string
    location               = optional(string)
    name                   = optional(string)
    namespace_type         = optional(string)
    packaging              = optional(string)
    path                   = optional(string)
    encryption_disabled    = optional(bool)
    override_artifact_name = optional(bool)
    artifact_identifier    = optional(string)
    bucket_owner_access    = optional(string)
  })
  default = {
    type = "NO_ARTIFACTS"
  }
}

variable "secondary_artifacts" {
  description = "Secondary artifacts, each with a unique artifact_identifier"
  type = list(object({
    artifact_identifier    = string
    type                   = string
    location               = optional(string)
    name                   = optional(string)
    namespace_type         = optional(string)
    packaging              = optional(string)
    path                   = optional(string)
    encryption_disabled    = optional(bool)
    override_artifact_name = optional(bool)
    bucket_owner_access    = optional(string)
  }))
  default = []
}

# --- Environment ---------------------------------------------------------------

variable "environment" {
  description = "Build environment. For Docker builds set privileged_mode = true. ARM builds use type ARM_CONTAINER with an aarch64 image"
  type = object({
    compute_type                = optional(string, "BUILD_GENERAL1_SMALL")
    image                       = optional(string, "aws/codebuild/amazonlinux-aarch64-standard:3.0")
    type                        = optional(string, "ARM_CONTAINER")
    image_pull_credentials_type = optional(string, "CODEBUILD")
    privileged_mode             = optional(bool, false)
    certificate                 = optional(string)
    host_kernel                 = optional(string)
    fleet_arn                   = optional(string)
    registry_credential = optional(object({
      credential          = string
      credential_provider = string
    }))
    docker_server = optional(object({
      compute_type       = string
      security_group_ids = optional(list(string))
    }))
    environment_variables = optional(list(object({
      name  = string
      value = string
      type  = optional(string, "PLAINTEXT")
    })), [])
  })
  default = {}
}

variable "cache" {
  description = "Build cache. type is NO_CACHE, S3 (needs location) or LOCAL (needs modes)"
  type = object({
    type            = optional(string, "NO_CACHE")
    location        = optional(string)
    modes           = optional(list(string))
    cache_namespace = optional(string)
  })
  default = null
}

variable "vpc_config" {
  description = "Run builds inside a VPC. The subnets need a NAT route or VPC endpoints to reach AWS APIs"
  type = object({
    vpc_id             = string
    subnets            = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "file_system_locations" {
  description = "EFS file systems mounted in the build"
  type = list(object({
    identifier    = optional(string)
    location      = optional(string)
    mount_options = optional(string)
    mount_point   = optional(string)
    type          = optional(string, "EFS")
  }))
  default = []
}

variable "build_batch_config" {
  description = "Batch build settings"
  type = object({
    service_role      = string
    combine_artifacts = optional(bool)
    timeout_in_mins   = optional(number)
    restrictions = optional(object({
      compute_types_allowed  = optional(list(string))
      maximum_builds_allowed = optional(number)
    }))
  })
  default = null
}

# --- Logs ----------------------------------------------------------------------

variable "cloudwatch_logs" {
  description = "CloudWatch Logs settings. group_name defaults to /aws/codebuild/<name>"
  type = object({
    status      = optional(string, "ENABLED")
    group_name  = optional(string)
    stream_name = optional(string)
  })
  default = {}
}

variable "create_log_group" {
  description = "Create the CloudWatch log group so retention and encryption are managed here"
  type        = bool
  default     = true
}

variable "log_group_retention_in_days" {
  description = "Retention of the build log group"
  type        = number
  default     = 30
}

variable "log_group_kms_key_id" {
  description = "KMS key ARN for the build log group"
  type        = string
  default     = null
}

variable "s3_logs" {
  description = "S3 build logs. location is <bucket>/<prefix> when status is ENABLED"
  type = object({
    status              = optional(string, "DISABLED")
    location            = optional(string)
    encryption_disabled = optional(bool)
    bucket_owner_access = optional(string)
  })
  default = {}
}

# --- Service role --------------------------------------------------------------

variable "create_service_role" {
  description = "Create the CodeBuild service role with a base policy built from the service_role_* lists"
  type        = bool
  default     = true
}

variable "service_role_arn" {
  description = "Existing service role ARN used when create_service_role is false"
  type        = string
  default     = null
}

variable "service_role_name" {
  description = "Service role name. Defaults to <name>-codebuild-role"
  type        = string
  default     = null
}

variable "service_role_path" {
  description = "IAM path of the service role"
  type        = string
  default     = "/"
}

variable "service_role_permissions_boundary" {
  description = "Permissions boundary ARN for the service role"
  type        = string
  default     = null
}

variable "service_role_s3_bucket_arns" {
  description = "S3 bucket ARNs the build reads and writes (source, artifacts, cache)"
  type        = list(string)
  default     = []
}

variable "service_role_ecr_repository_arns" {
  description = "ECR repository ARNs the build pushes to and pulls from"
  type        = list(string)
  default     = []
}

variable "service_role_kms_key_arns" {
  description = "KMS key ARNs the build uses"
  type        = list(string)
  default     = []
}

variable "service_role_secret_arns" {
  description = "Secrets Manager secret ARNs read by SECRETS_MANAGER environment variables"
  type        = list(string)
  default     = []
}

variable "service_role_ssm_parameter_arns" {
  description = "SSM parameter ARNs read by PARAMETER_STORE environment variables"
  type        = list(string)
  default     = []
}

variable "service_role_managed_policy_arns" {
  description = "Managed policy ARNs attached to the service role"
  type        = list(string)
  default     = []
}

variable "service_role_inline_policies" {
  description = "Extra inline policies keyed by policy name (JSON documents)"
  type        = map(string)
  default     = {}
}

# --- Webhook -------------------------------------------------------------------

variable "create_webhook" {
  description = "Create a source webhook. Not usable with GitLab in Regions without CodeConnections"
  type        = bool
  default     = false
}

variable "webhook_build_type" {
  description = "BUILD or BUILD_BATCH"
  type        = string
  default     = null
}

variable "webhook_manual_creation" {
  description = "Return payload_url and secret instead of creating the webhook in the source provider"
  type        = bool
  default     = null
}

variable "webhook_branch_filter" {
  description = "Branch regex. Prefer webhook_filter_groups"
  type        = string
  default     = null
}

variable "webhook_filter_groups" {
  description = "Filter groups; each inner list is one group of filters (type EVENT, HEAD_REF, BASE_REF, FILE_PATH, ...)"
  type = list(list(object({
    type                    = string
    pattern                 = string
    exclude_matched_pattern = optional(bool)
  })))
  default = []
}

variable "webhook_scope_configuration" {
  description = "Organization or global webhook scope (GitHub)"
  type = object({
    name   = string
    scope  = string
    domain = optional(string)
  })
  default = null
}

variable "webhook_pull_request_build_policy" {
  description = "Comment-based approval for pull request builds"
  type = object({
    requires_comment_approval = string
    approver_roles            = optional(list(string))
  })
  default = null
}
