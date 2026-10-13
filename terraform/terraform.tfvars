#provider.tf
aws_default_tags = {
  ProjectName  = "POC Maven DoFS on AWS"
  Organization = "Kalbe Nutritionals"
  Creator      = "CDT - Cloud Engineering Team"
  CreatedFrom  = "Infrastructure as Code"
  IaCTool      = "Terraform"
  AccountID    = "908027374739"
}
region = "ap-southeast-3"

#main.tf
#Notification
notification_emails        = [] # TBD (DDD T28) - recipients of alarm, GuardDuty, CodeDeploy and AWS Health emails
budget_notification_emails = [] # TBD (DDD T27) - recipients of budget and cost anomaly emails

#Project Phase Toggles
create_loadtest_instance       = false # Enable for the load test phase
create_datasync_agent_instance = false # Enable once the NAS details are confirmed (DDD T22)
datasync_agent_activation_key  = null  # Set after activating the agent instance
