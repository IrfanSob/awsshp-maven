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

#Global Environment
org     = "shp"
env     = "dev"
project = "maven"

#main.tf
#Notification
notification_emails = [
  "Irfan.sobarkah@kalbenutritionals.com",
  "syarif.hidayat@kalbenutritionals.com"
]
db_notification_emails = [
  "Irfan.sobarkah@kalbenutritionals.com",
  "syarif.hidayat@kalbenutritionals.com",
  "novaldi.valentino@kalbenutritionals.com"
]
budget_notification_emails = ["Jerie.alhamdani@kalbenutritionals.com"]

#Project Phase Toggles
create_loadtest_instance       = false # Enable for the load test phase
create_datasync_agent_instance = false # Enable once the NAS details are confirmed (DDD T22)
datasync_agent_activation_key  = null  # Set after activating the agent instance
