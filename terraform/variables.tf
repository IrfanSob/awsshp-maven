# Provider.tf
variable "aws_default_tags" {
  description = "Default tags for all AWS resources"
  type        = map(string)
}

variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
}

# Main.tf
# Notification
variable "notification_emails" {
  description = "Email endpoints subscribed to the notification SNS topic (CloudWatch alarms, GuardDuty, CodeDeploy and AWS Health). Each address must confirm within 48 hours"
  type        = list(string)
}

variable "budget_notification_emails" {
  description = "Addresses for budget and cost anomaly alerts. Sent directly, not through SNS"
  type        = list(string)
}

# Project Phase Toggles
variable "create_loadtest_instance" {
  description = "Create the temporary k6 load test instance"
  type        = bool
  default     = false
}

variable "create_datasync_agent_instance" {
  description = "Create the DataSync agent instance and the DataSync interface endpoint"
  type        = bool
  default     = false
}

variable "datasync_agent_activation_key" {
  description = "Activation key of the DataSync agent instance. Null until the agent has been activated; then the agent, NAS location and task are created"
  type        = string
  default     = null
}
