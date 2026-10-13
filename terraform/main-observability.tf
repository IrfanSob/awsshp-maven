# S3 Bucket for Logs
module "s3_logs" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-s3-bucket?ref=main"

  bucket_name       = "maven-logs-908027374739"
  versioning_status = "Disabled"

  enable_server_side_encryption = true
  sse_algorithm                 = "AES256"

  attach_deny_insecure_transport_policy = true
  attach_lb_log_delivery_policy         = true
  lb_log_delivery_principal_type        = "service"
  attach_cloudtrail_log_delivery_policy = true
  cloudtrail_source_arns                = ["arn:aws:cloudtrail:${var.region}:908027374739:trail/maven-trail"]

  lifecycle_rules = [
    {
      id      = "expire-logs"
      enabled = true

      filter = {
        prefix = ""
      }

      expiration = {
        days = 90 # Log retention for the POC period
      }

      abort_incomplete_multipart_upload_days = 7
    }
  ]

  tags = {
    "Resource" = "S3"
  }
}

# CloudTrail Management Events Trail
module "cloudtrail_management_events" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-cloudtrail-management-events-v6?ref=main"

  trail_name                 = "maven-trail"
  create_s3_bucket           = false
  s3_bucket_name             = module.s3_logs.bucket_id
  kms_key_arn                = module.kms_cmk.kms_key_arn
  is_multi_region_trail      = true
  enable_log_file_validation = true

  tags = {
    "Resource" = "CloudTrail"
  }

  depends_on = [module.s3_logs]
}

# SNS Topic - Notifications (CloudWatch alarms and EventBridge rules)
module "sns_notifications" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-sns-topic-v6?ref=main"

  name              = "maven-notifications"
  display_name      = "Maven POC Notifications"
  kms_master_key_id = module.kms_cmk.kms_key_arn

  publisher_service_principals = ["events.amazonaws.com", "cloudwatch.amazonaws.com"]

  subscriptions = {
    for email in var.notification_emails : email => {
      protocol = "email"
      endpoint = email
    }
  }

  tags = {
    "Resource" = "SNS"
  }
}

# GuardDuty
module "guardduty" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-guardduty?ref=main"

  enable_kubernetes_protection = false

  tags = {
    "Resource" = "GuardDuty"
  }
}

# EventBridge - GuardDuty, CodeDeploy and AWS Health Notifications
module "eventbridge_notifications" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-eventbridge-rule-v6?ref=main"

  rules = {
    "guardduty-findings" = {
      name        = "maven-guardduty-findings"
      description = "GuardDuty findings with severity 7 (High) and above"
      event_pattern = jsonencode({
        source      = ["aws.guardduty"]
        detail-type = ["GuardDuty Finding"]
        detail = {
          severity = [{ numeric = [">=", 7] }] # Minimum severity notified
        }
      })

      targets = {
        "sns" = {
          arn = module.sns_notifications.topic_arn
          input_transformer = {
            input_paths = {
              severity = "$.detail.severity"
              type     = "$.detail.type"
              title    = "$.detail.title"
              account  = "$.detail.accountId"
              region   = "$.detail.region"
            }
            input_template = "\"GuardDuty finding <type> (severity <severity>) in account <account>, <region>: <title>\""
          }
        }
      }
    }
    "codedeploy-failure" = {
      name        = "maven-codedeploy-failure"
      description = "CodeDeploy deployment failures of the Maven ECS services"
      event_pattern = jsonencode({
        source      = ["aws.codedeploy"]
        detail-type = ["CodeDeploy Deployment State-change Notification"]
        detail = {
          application = ["maven-ecs"]
          state       = ["FAILURE"]
        }
      })

      targets = {
        "sns" = {
          arn = module.sns_notifications.topic_arn
          input_transformer = {
            input_paths = {
              application = "$.detail.application"
              group       = "$.detail.deploymentGroup"
              deployment  = "$.detail.deploymentId"
              region      = "$.region"
            }
            input_template = "\"CodeDeploy deployment <deployment> of <application>/<group> failed in <region>\""
          }
        }
      }
    }
    "aws-health" = {
      name        = "maven-aws-health"
      description = "AWS Health events affecting this account"
      event_pattern = jsonencode({
        source      = ["aws.health"]
        detail-type = ["AWS Health Event"]
      })

      targets = {
        "sns" = {
          arn = module.sns_notifications.topic_arn
          input_transformer = {
            input_paths = {
              service  = "$.detail.service"
              category = "$.detail.eventTypeCategory"
              type     = "$.detail.eventTypeCode"
              region   = "$.region"
            }
            input_template = "\"AWS Health <category> event <type> for <service> in <region>\""
          }
        }
      }
    }
  }

  tags = {
    "Resource" = "EventBridge"
  }
}

# Budgets
module "budgets" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-budgets?ref=main"

  notification_email_addresses = var.budget_notification_emails

  budgets = {
    "maven-monthly-budget" = {
      budget_type  = "COST"
      limit_amount = "1300" # USD per month
      limit_unit   = "USD"
      time_unit    = "MONTHLY"

      cost_types = {
        include_credit = false
      }

      notifications = [
        {
          threshold         = 80
          threshold_type    = "PERCENTAGE"
          notification_type = "FORECASTED"
        },
        {
          threshold         = 100
          threshold_type    = "PERCENTAGE"
          notification_type = "ACTUAL"
        }
      ]
    }
  }

  tags = {
    "Resource" = "Budgets"
  }
}

# Cost Anomaly Detection
module "cost_anomaly_detection" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-cost-anomaly-detection?ref=main"

  name_prefix      = "maven"
  create_sns_topic = false

  monitors = {
    "services" = {
      name = "maven-service-monitor"
    }
  }

  subscriptions = {
    "daily-email" = {
      name                       = "maven-anomaly-daily"
      frequency                  = "DAILY"
      monitor_keys               = ["services"]
      subscriber_email_addresses = var.budget_notification_emails
      threshold_value            = 5 # USD above expected spend; the 15% condition needs the cost anomaly module update
    }
  }

  tags = {
    "Resource" = "CostAnomalyDetection"
  }
}

# IAM Role - Prometheus EC2 (ECS service discovery)
module "iam_role_monitoring" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-iam-role?ref=main"

  name                    = "maven-monitoring-ec2-role"
  description             = "Prometheus and Grafana instance: SSM, CloudWatch agent and ECS service discovery"
  trusted_services        = ["ec2.amazonaws.com"]
  create_instance_profile = true
  instance_profile_name   = "maven-monitoring-ec2-profile"

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]

  inline_policies = {
    "prometheus-ecs-discovery" = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "ecs:ListClusters",
            "ecs:ListServices",
            "ecs:ListTasks",
            "ecs:DescribeClusters",
            "ecs:DescribeServices",
            "ecs:DescribeTasks",
            "ecs:DescribeTaskDefinition",
            "ecs:DescribeContainerInstances",
            "ec2:DescribeInstances",
            "ec2:DescribeNetworkInterfaces"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "cloudwatch:GetMetricData",
            "cloudwatch:ListMetrics",
            "cloudwatch:GetMetricStatistics",
            "logs:DescribeLogGroups",
            "logs:GetLogEvents",
            "logs:StartQuery",
            "logs:GetQueryResults",
            "tag:GetResources"
          ]
          Resource = "*"
        }
      ]
    })
  }

  tags = {
    "Resource" = "IAM"
  }
}

# AMI - Amazon Linux 2023 (latest)
data "aws_ssm_parameter" "al2023_x86_64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# EC2 Instance - Prometheus and Grafana
module "ec2_monitoring" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-ec2-instances?ref=main"

  create_iam_role                    = false
  existing_iam_instance_profile_name = module.iam_role_monitoring.instance_profile_name

  instances = {
    "monitoring" = {
      ami_id             = data.aws_ssm_parameter.al2023_x86_64.insecure_value
      instance_type      = "t3.large"
      subnet_id          = module.vpc.private_app_subnet_ids[0]
      security_group_ids = [module.sg_monitoring.security_group_id]

      root_block_device = {
        volume_type = "gp3"
        volume_size = 30
        encrypted   = true
        kms_key_id  = module.kms_cmk.kms_key_arn
      }

      ebs_volumes = [
        {
          device_name = "/dev/sdf"
          size        = 50 # Prometheus TSDB volume in GB
          type        = "gp3"
          encrypted   = true
          kms_key_id  = module.kms_cmk.kms_key_arn
          tags = {
            "Purpose" = "Prometheus TSDB"
          }
        }
      ]

      tags = {
        "Name"    = "maven-monitoring"
        "Purpose" = "Prometheus and Grafana"
        "Backup"  = "daily-ami"
      }
    }
  }

  tags = {
    "Resource" = "EC2"
  }
}

# AWS Backup - Prometheus and Grafana AMI
module "backup_monitoring" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-backup?ref=main"

  name_prefix       = "maven"
  backup_vault_name = "maven-backup-vault"
  backup_plan_name  = "maven-ec2-daily"
  kms_key_arn       = module.kms_cmk.kms_key_arn

  backup_rules = [
    {
      rule_name    = "daily-ami"
      schedule     = "cron(0 17 * * ? *)" # Daily at 17:00 UTC (00:00 WIB)
      delete_after = 3                    # Retention in days
    }
  ]

  backup_selections = {
    "monitoring" = {
      name      = "maven-monitoring"
      resources = [module.ec2_monitoring.instance_arns["monitoring"]]
    }
  }

  tags = {
    "Resource" = "Backup"
  }
}

# CloudWatch Alarms
module "cloudwatch_alarms" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-cloudwatch-alarms-v6?ref=main"

  alarm_name_prefix     = "maven"
  default_alarm_actions = [module.sns_notifications.topic_arn]
  default_ok_actions    = [module.sns_notifications.topic_arn]

  metric_alarms = merge(
    {
      "dofs-unhealthy-hosts-blue" = {
        alarm_description   = "Unhealthy targets in dofs blue target group"
        namespace           = "AWS/ApplicationELB"
        metric_name         = "UnHealthyHostCount"
        dimensions          = { LoadBalancer = module.alb_internal.lb_arn_suffix, TargetGroup = module.alb_internal.target_group_arn_suffixes["dofs-blue"] }
        statistic           = "Maximum"
        period              = 60
        evaluation_periods  = 3
        comparison_operator = "GreaterThanThreshold"
        threshold           = 0
        treat_missing_data  = "notBreaching"
      }
      "dofs-unhealthy-hosts-green" = {
        alarm_description   = "Unhealthy targets in dofs green target group"
        namespace           = "AWS/ApplicationELB"
        metric_name         = "UnHealthyHostCount"
        dimensions          = { LoadBalancer = module.alb_internal.lb_arn_suffix, TargetGroup = module.alb_internal.target_group_arn_suffixes["dofs-green"] }
        statistic           = "Maximum"
        period              = 60
        evaluation_periods  = 3
        comparison_operator = "GreaterThanThreshold"
        threshold           = 0
        treat_missing_data  = "notBreaching"
      }
      "shortenurl-unhealthy-hosts-blue" = {
        alarm_description   = "Unhealthy targets in shortenurl blue target group"
        namespace           = "AWS/ApplicationELB"
        metric_name         = "UnHealthyHostCount"
        dimensions          = { LoadBalancer = module.alb_internal.lb_arn_suffix, TargetGroup = module.alb_internal.target_group_arn_suffixes["shortenurl-blue"] }
        statistic           = "Maximum"
        period              = 60
        evaluation_periods  = 3
        comparison_operator = "GreaterThanThreshold"
        threshold           = 0
        treat_missing_data  = "notBreaching"
      }
      "shortenurl-unhealthy-hosts-green" = {
        alarm_description   = "Unhealthy targets in shortenurl green target group"
        namespace           = "AWS/ApplicationELB"
        metric_name         = "UnHealthyHostCount"
        dimensions          = { LoadBalancer = module.alb_internal.lb_arn_suffix, TargetGroup = module.alb_internal.target_group_arn_suffixes["shortenurl-green"] }
        statistic           = "Maximum"
        period              = 60
        evaluation_periods  = 3
        comparison_operator = "GreaterThanThreshold"
        threshold           = 0
        treat_missing_data  = "notBreaching"
      }
    },
    {
      "api-latency-p95" = {
        alarm_description   = "API Gateway p95 latency above 500 ms"
        namespace           = "AWS/ApiGateway"
        metric_name         = "Latency"
        dimensions          = { ApiName = "maven-api", Stage = "poc" }
        extended_statistic  = "p95"
        period              = 60
        evaluation_periods  = 3
        datapoints_to_alarm = 3
        comparison_operator = "GreaterThanThreshold"
        threshold           = 500 # Milliseconds
        treat_missing_data  = "notBreaching"
      }
      "api-5xx-rate" = {
        alarm_description   = "API Gateway 5XX error rate above 1% for 5 minutes"
        namespace           = "AWS/ApiGateway"
        metric_name         = "5XXError"
        dimensions          = { ApiName = "maven-api", Stage = "poc" }
        statistic           = "Average"
        period              = 60
        evaluation_periods  = 5
        datapoints_to_alarm = 5
        comparison_operator = "GreaterThanThreshold"
        threshold           = 0.01 # Error rate, 0.01 = 1%
        treat_missing_data  = "notBreaching"
      }
      "alb-response-time-p95" = {
        alarm_description   = "Internal ALB p95 target response time above 500 ms"
        namespace           = "AWS/ApplicationELB"
        metric_name         = "TargetResponseTime"
        dimensions          = { LoadBalancer = module.alb_internal.lb_arn_suffix }
        extended_statistic  = "p95"
        period              = 60
        evaluation_periods  = 3
        datapoints_to_alarm = 3
        comparison_operator = "GreaterThanThreshold"
        threshold           = 0.5 # Seconds
        treat_missing_data  = "notBreaching"
      }
      "alb-target-5xx" = {
        alarm_description   = "Internal ALB target 5XX responses above 50 in 5 minutes"
        namespace           = "AWS/ApplicationELB"
        metric_name         = "HTTPCode_Target_5XX_Count"
        dimensions          = { LoadBalancer = module.alb_internal.lb_arn_suffix }
        statistic           = "Sum"
        period              = 300
        evaluation_periods  = 1
        comparison_operator = "GreaterThanThreshold"
        threshold           = 50 # 5XX count per 5 minutes
        treat_missing_data  = "notBreaching"
      }
      "aurora-capacity-max" = {
        alarm_description   = "Aurora Serverless v2 at maximum ACU for 10 minutes"
        namespace           = "AWS/RDS"
        metric_name         = "ServerlessDatabaseCapacity"
        dimensions          = { DBClusterIdentifier = module.aurora.cluster_id }
        statistic           = "Average"
        period              = 60
        evaluation_periods  = 10
        comparison_operator = "GreaterThanOrEqualToThreshold"
        threshold           = 4 # Aurora maximum ACU
      }
      "aurora-cpu-high" = {
        alarm_description   = "Aurora CPU above 80% for 10 minutes"
        namespace           = "AWS/RDS"
        metric_name         = "CPUUtilization"
        dimensions          = { DBClusterIdentifier = module.aurora.cluster_id }
        statistic           = "Average"
        period              = 60
        evaluation_periods  = 10
        comparison_operator = "GreaterThanThreshold"
        threshold           = 80 # CPU %
      }
      "valkey-cpu-high" = {
        alarm_description   = "Valkey engine CPU above 80% for 5 minutes"
        namespace           = "AWS/ElastiCache"
        metric_name         = "EngineCPUUtilization"
        dimensions          = { ReplicationGroupId = module.valkey.replication_group_id }
        statistic           = "Average"
        period              = 60
        evaluation_periods  = 5
        comparison_operator = "GreaterThanThreshold"
        threshold           = 80 # CPU %
      }
      "valkey-memory-high" = {
        alarm_description   = "Valkey memory usage above 80%"
        namespace           = "AWS/ElastiCache"
        metric_name         = "DatabaseMemoryUsagePercentage"
        dimensions          = { ReplicationGroupId = module.valkey.replication_group_id }
        statistic           = "Average"
        period              = 60
        evaluation_periods  = 5
        comparison_operator = "GreaterThanThreshold"
        threshold           = 80 # Memory %
      }
      "monitoring-status-check" = {
        alarm_description   = "Prometheus and Grafana instance status check failed"
        namespace           = "AWS/EC2"
        metric_name         = "StatusCheckFailed"
        dimensions          = { InstanceId = module.ec2_monitoring.instance_ids["monitoring"] }
        statistic           = "Maximum"
        period              = 60
        evaluation_periods  = 2
        comparison_operator = "GreaterThanOrEqualToThreshold"
        threshold           = 1
      }
    },
    {
      "aurora-connections-high" = {
        alarm_description   = "Aurora connections above 80% of max_connections"
        namespace           = "AWS/RDS"
        metric_name         = "DatabaseConnections"
        dimensions          = { DBClusterIdentifier = module.aurora.cluster_id }
        statistic           = "Maximum"
        period              = 60
        evaluation_periods  = 5
        comparison_operator = "GreaterThanThreshold"
        threshold           = 720 # 80% of max_connections (about 900 at 4 ACU); confirm (DDD T28)
      }
    },
    { for k, v in {
      "vpn-tunnel-down" = {
        alarm_description   = "Site-to-Site VPN tunnels down"
        namespace           = "AWS/VPN"
        metric_name         = "TunnelState"
        dimensions          = { VpnId = try(module.vpn_onprem[0].vpn_connection_id, "") }
        statistic           = "Maximum"
        period              = 300
        evaluation_periods  = 2
        comparison_operator = "LessThanThreshold"
        threshold           = 1
        treat_missing_data  = "breaching"
      }
    } : k => v if length(module.vpn_onprem) > 0 },
    { for k, v in {
      "loadtest-status-check" = {
        alarm_description   = "k6 load test instance status check failed"
        namespace           = "AWS/EC2"
        metric_name         = "StatusCheckFailed"
        dimensions          = { InstanceId = try(module.ec2_tools.instance_ids["loadtest"], "") }
        statistic           = "Maximum"
        period              = 60
        evaluation_periods  = 2
        comparison_operator = "GreaterThanOrEqualToThreshold"
        threshold           = 1
      }
    } : k => v if var.create_loadtest_instance },
    { for k, v in {
      "datasync-agent-status-check" = {
        alarm_description   = "DataSync agent instance status check failed"
        namespace           = "AWS/EC2"
        metric_name         = "StatusCheckFailed"
        dimensions          = { InstanceId = try(module.ec2_tools.instance_ids["datasync-agent"], "") }
        statistic           = "Maximum"
        period              = 60
        evaluation_periods  = 2
        comparison_operator = "GreaterThanOrEqualToThreshold"
        threshold           = 1
      }
    } : k => v if var.create_datasync_agent_instance }
  )

  tags = {
    "Resource" = "CloudWatch"
  }
}
