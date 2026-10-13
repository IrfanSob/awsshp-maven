# CMK
module "kms_cmk" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-cmk-v6?ref=main"

  description             = "KMS CMK for the Maven POC"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  key_name                = "cmk-shpdev-maven-908027374739"
  key_alias               = "cmk-shpdev-maven-908027374739"

  additional_service_principals = ["events.amazonaws.com", "cloudwatch.amazonaws.com"]

  tags = {
    "Resource" = "CMK"
  }
}

# IAM GROUPS
# superadmin
module "iam_group_superadmin" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-iam-user-group?ref=main"

  group_name = "superadmin"

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess"
  ]

  customer_managed_policies = {
    "Force_MFA" = {
      description = "Allows users to manage their own passwords and MFA devices but nothing else unless they authenticate with MFA."
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid      = "AllowViewAccountInfo"
            Effect   = "Allow"
            Action   = ["iam:GetAccountPasswordPolicy", "iam:ListVirtualMFADevices"]
            Resource = "*"
          },
          {
            Sid      = "AllowManageOwnPasswords"
            Effect   = "Allow"
            Action   = ["iam:ChangePassword", "iam:GetUser"]
            Resource = "arn:aws:iam::*:user/$${aws:username}"
          },
          {
            Sid      = "AllowManageOwnAccessKeys"
            Effect   = "Allow"
            Action   = ["iam:CreateAccessKey", "iam:DeleteAccessKey", "iam:ListAccessKeys", "iam:UpdateAccessKey", "iam:GetAccessKeyLastUsed"]
            Resource = "arn:aws:iam::*:user/$${aws:username}"
          },
          {
            Sid      = "AllowManageOwnVirtualMFADevice"
            Effect   = "Allow"
            Action   = ["iam:CreateVirtualMFADevice"]
            Resource = "arn:aws:iam::*:mfa/*"
          },
          {
            Sid      = "AllowManageOwnUserMFA"
            Effect   = "Allow"
            Action   = ["iam:DeactivateMFADevice", "iam:EnableMFADevice", "iam:ListMFADevices", "iam:ResyncMFADevice"]
            Resource = "arn:aws:iam::*:user/$${aws:username}"
          },
          {
            Sid    = "DenyAllExceptListedIfNoMFA"
            Effect = "Deny"
            NotAction = [
              "iam:CreateVirtualMFADevice",
              "iam:ChangePassword",
              "iam:EnableMFADevice",
              "iam:GetAccountPasswordPolicy",
              "iam:GetUser",
              "iam:GetMFADevice",
              "iam:ListMFADevices",
              "iam:ListVirtualMFADevices",
              "iam:ResyncMFADevice",
              "sts:GetSessionToken"
            ]
            Resource = "*"
            Condition = {
              BoolIfExists = {
                "aws:MultiFactorAuthPresent" = "false"
              }
            }
          }
        ]
      })
    }
  }

  users = {
    "sob.irfan"  = {}
    "hid.syarif" = {}
  }

  tags = {
    "Resource" = "IAM"
  }
}

# dbadmin
module "iam_group_dbadmin" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-iam-user-group?ref=main"

  group_name = "dbadmin"

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/job-function/DatabaseAdministrator",
    module.iam_group_superadmin.customer_managed_policy_arns["Force_MFA"]
  ]

  users = {
    "val.novaldi" = {}
  }

  tags = {
    "Resource" = "IAM"
  }
}

# Secrets Manager (Aurora master credential is managed by RDS)
module "secrets" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-secrets-manager-v6?ref=main"

  kms_key_id              = module.kms_cmk.kms_key_arn
  recovery_window_in_days = 7

  secrets = {
    "shortendb" = {
      name        = "shortendb/aurora"
      description = "Aurora PostgreSQL application credential for ShortenDB"

      generate_random_password = {
        length  = 32
        special = false
      }
      generated_password_json_key = "password"
      secret_string_template = {
        username = "" # TBD (Kalbe, DDD T7) - application username for ShortenDB
        dbname   = "shortendb"
        engine   = "postgres"
        host     = module.aurora.cluster_endpoint
        port     = tostring(module.aurora.cluster_port)
      }
    }
    "mavendb" = {
      name        = "mavendb/aurora"
      description = "Aurora PostgreSQL application credential for MavenDB"

      generate_random_password = {
        length  = 32
        special = false
      }
      generated_password_json_key = "password"
      secret_string_template = {
        username = "" # TBD (Kalbe, DDD T7) - application username for MavenDB
        dbname   = "mavendb"
        engine   = "postgres"
        host     = module.aurora.cluster_endpoint
        port     = tostring(module.aurora.cluster_port)
      }
    }
    "valkey" = {
      name        = "cache-valkey/auth"
      description = "ElastiCache Valkey AUTH token"

      generate_random_password = {
        length  = 64
        special = false
      }
      generated_password_json_key = "password"
      secret_string_template = {
        username = "default"
        port     = "6379"
      }
    }
    "cognito-app" = {
      name        = "cognito/shpdev-maven-app"
      description = "Cognito app client credential of the Maven application"
    }
  }

  secret_values = {
    "cognito-app" = {
      secret_string = jsonencode({
        TOKEN_URL     = module.cognito.oauth2_token_url
        CLIENT_ID     = module.cognito.client_ids["app"]
        CLIENT_SECRET = module.cognito.client_secrets["app"]
      })
    }
  }

  tags = {
    "Resource" = "SecretsManager"
  }
}

# Aurora PostgreSQL Serverless v2
module "aurora" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-rds-aurora-v6?ref=main"

  cluster_identifier = "shpdev-maven-db"
  engine             = "aurora-postgresql"
  engine_version     = null # TBD (Kalbe, DDD T19) - same or newer major version than on-premises PostgreSQL
  database_name      = null # TBD (Kalbe, DDD T19) - initial database name
  master_username    = "mavenadmin"

  manage_master_user_password   = true
  master_user_secret_kms_key_id = module.kms_cmk.kms_key_arn

  subnet_ids             = module.vpc.private_app_subnet_ids
  vpc_security_group_ids = [module.sg_aurora.security_group_id]

  storage_encrypted = true
  kms_key_id        = module.kms_cmk.kms_key_arn

  serverlessv2_scaling_configuration = {
    min_capacity = 1
    max_capacity = 4
  }

  cluster_instances = {
    "writer" = {
      availability_zone = "ap-southeast-3a"
    }
  }

  backup_retention_period      = 7
  preferred_backup_window      = "18:00-19:00"
  preferred_maintenance_window = null # TBD (DDD T19) - must not overlap the backup window
  deletion_protection          = true

  database_insights_mode                = "standard"
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = module.kms_cmk.kms_key_arn
  performance_insights_retention_period = 7

  enabled_cloudwatch_logs_exports        = ["postgresql"]
  create_cloudwatch_log_groups           = true
  cloudwatch_log_group_retention_in_days = 30

  tags = {
    "Resource" = "RDS"
  }
}

# ElastiCache Valkey
module "valkey" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-elasticache?ref=main"

  name           = "shpdev-maven-valkey"
  description    = "Maven cache (Valkey)"
  engine         = "valkey"
  engine_version = null # TBD (Kalbe, DDD T20) - null uses the latest version
  node_type      = "cache.m6g.large"

  subnet_ids         = module.vpc.private_app_subnet_ids
  security_group_ids = [module.sg_valkey.security_group_id]

  num_cache_clusters         = 1
  automatic_failover_enabled = false
  multi_az_enabled           = false

  at_rest_encryption_enabled = true
  kms_key_id                 = module.kms_cmk.kms_key_arn
  transit_encryption_enabled = true
  auth_token                 = module.secrets.generated_passwords["valkey"]

  snapshot_retention_limit = 1
  snapshot_window          = "17:00-18:00"
  maintenance_window       = "sat:19:00-sat:20:00"

  log_delivery_configurations = [
    {
      destination      = aws_cloudwatch_log_group.valkey_slow_log.name
      destination_type = "cloudwatch-logs"
      log_format       = "json"
      log_type         = "slow-log"
    }
  ]

  tags = {
    "Resource" = "ElastiCache"
  }
}

# CloudWatch Log Group - Valkey Slow Log
resource "aws_cloudwatch_log_group" "valkey_slow_log" {
  name              = "/elasticache/shpdev-maven-valkey/slow-log"
  retention_in_days = 30 # Slow log retention

  tags = {
    "Resource" = "CloudWatch"
  }
}

# S3 Bucket - Assets (NAS migration target)
module "s3_assets" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-s3-bucket?ref=main"

  bucket_name       = "shpdev-maven"
  versioning_status = "Disabled"

  enable_server_side_encryption = true
  sse_algorithm                 = "aws:kms"
  kms_key_arn                   = module.kms_cmk.kms_key_arn
  bucket_key_enabled            = true

  attach_deny_insecure_transport_policy = true

  tags = {
    "Resource" = "S3"
  }
}

# S3 Bucket - CI/CD Artifacts (GitLab CI uploads source bundles and deployment specs)
module "s3_cicd" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-s3-bucket?ref=main"

  bucket_name       = "shpdev-maven-cicd-artifacts-908027374739"
  versioning_status = "Enabled"

  enable_server_side_encryption = true
  sse_algorithm                 = "aws:kms"
  kms_key_arn                   = module.kms_cmk.kms_key_arn
  bucket_key_enabled            = true

  attach_deny_insecure_transport_policy = true

  lifecycle_rules = [
    {
      id      = "expire-old-artifacts"
      enabled = true

      filter = {
        prefix = ""
      }

      noncurrent_version_expiration = {
        noncurrent_days = 30
      }

      abort_incomplete_multipart_upload_days = 7
    }
  ]

  tags = {
    "Resource" = "S3"
  }
}

# ECR
module "ecr" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-ecr-private-repository?ref=main"

  repositories         = ["maven-dofs", "maven-shortenurl"]
  image_tag_mutability = "IMMUTABLE"
  scan_on_push         = true

  encryption_type = "KMS"
  kms_key_arn     = module.kms_cmk.kms_key_arn

  create_lifecycle_policy    = true
  max_image_count            = 2 # Images kept per repository (current and rollback)
  untagged_image_expiry_days = 7

  tags = {
    "Resource" = "ECR"
  }
}

# ACM Certificate (DNS validation records are created by Kalbe)
module "acm_kalbe" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-acm-certificate?ref=main"

  domain_name               = "kalbenutritionals.web.id"
  subject_alternative_names = ["*.kalbenutritionals.web.id"]
  validation_method         = "DNS"

  tags = {
    "Resource" = "ACM"
  }
}

# Internal ALB
module "alb_internal" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-load-balancer?ref=main"

  name               = "shpdev-maven-alb-internal"
  load_balancer_type = "application"
  internal           = true
  ip_address_type    = "ipv4"

  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.private_app_subnet_ids
  security_group_ids = [module.sg_alb.security_group_id]

  enable_deletion_protection = false
  drop_invalid_header_fields = true
  idle_timeout               = 60

  access_logs = {
    bucket  = module.s3_logs.bucket_id
    prefix  = "alb-internal"
    enabled = true
  }

  target_groups = {
    "dofs-blue" = {
      name                 = "tg-maven-dofs-blue"
      port                 = 80
      protocol             = "HTTP"
      target_type          = "ip"
      deregistration_delay = 30

      health_check = {
        path     = "/healthcheck" # TBD (Kalbe) - dofs health check path
        protocol = "HTTP"
        matcher  = "200"
        interval = 15
        timeout  = 5
      }
    }
    "dofs-green" = {
      name                 = "tg-maven-dofs-green"
      port                 = 80
      protocol             = "HTTP"
      target_type          = "ip"
      deregistration_delay = 30

      health_check = {
        path     = "/healthcheck" # TBD (Kalbe) - dofs health check path
        protocol = "HTTP"
        matcher  = "200"
        interval = 15
        timeout  = 5
      }
    }
    "shortenurl-blue" = {
      name                 = "tg-maven-shortenurl-blue"
      port                 = 80
      protocol             = "HTTP"
      target_type          = "ip"
      deregistration_delay = 30

      health_check = {
        path     = "/healthcheck" # TBD (Kalbe) - shortenurl health check path
        protocol = "HTTP"
        matcher  = "200"
        interval = 15
        timeout  = 5
      }
    }
    "shortenurl-green" = {
      name                 = "tg-maven-shortenurl-green"
      port                 = 80
      protocol             = "HTTP"
      target_type          = "ip"
      deregistration_delay = 30

      health_check = {
        path     = "/healthcheck" # TBD (Kalbe) - shortenurl health check path
        protocol = "HTTP"
        matcher  = "200"
        interval = 15
        timeout  = 5
      }
    }
  }

  listeners = {
    "dofs" = {
      port                          = 8443
      protocol                      = "HTTPS"
      certificate_arn               = module.acm_kalbe.certificate_arn
      action_type                   = "forward"
      target_group_key              = "dofs-blue"
      ignore_default_action_changes = true
    }
    "dofs-test" = {
      port                          = 9443
      protocol                      = "HTTPS"
      certificate_arn               = module.acm_kalbe.certificate_arn
      action_type                   = "forward"
      target_group_key              = "dofs-green"
      ignore_default_action_changes = true
    }
    "shortenurl" = {
      port                          = 8444
      protocol                      = "HTTPS"
      certificate_arn               = module.acm_kalbe.certificate_arn
      action_type                   = "forward"
      target_group_key              = "shortenurl-blue"
      ignore_default_action_changes = true
    }
    "shortenurl-test" = {
      port                          = 9444
      protocol                      = "HTTPS"
      certificate_arn               = module.acm_kalbe.certificate_arn
      action_type                   = "forward"
      target_group_key              = "shortenurl-green"
      ignore_default_action_changes = true
    }
  }

  tags = {
    "Resource" = "LoadBalancer"
  }
}

# ECS Cluster (Fargate) - third service maven-backend-3 is TBD (Kalbe, DDD T17 name and API path)
module "ecs" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-ecs?ref=main"

  cluster_name       = "shpdev-maven-cluster"
  container_insights = "disabled"

  create_service_linked_role = true

  enable_fargate_capacity_provider = true
  default_capacity_provider_strategy = [
    {
      capacity_provider = "FARGATE"
      weight            = 1
    }
  ]

  create_task_execution_role = true
  task_execution_role_inline_policies = {
    "read-app-secrets" = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = ["secretsmanager:GetSecretValue"]
          Resource = [
            module.aurora.cluster_master_user_secret_arn,
            module.secrets.secret_arns["shortendb"],
            module.secrets.secret_arns["mavendb"],
            module.secrets.secret_arns["valkey"],
            module.secrets.secret_arns["cognito-app"]
          ]
        },
        {
          Effect   = "Allow"
          Action   = ["kms:Decrypt"]
          Resource = [module.kms_cmk.kms_key_arn]
        }
      ]
    })
  }

  create_task_role = true
  task_role_managed_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
  task_role_inline_policies = {
    "app-assets-bucket" = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
          Resource = [module.s3_assets.bucket_arn, "${module.s3_assets.bucket_arn}/*"]
        },
        {
          Effect   = "Allow"
          Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
          Resource = [module.kms_cmk.kms_key_arn]
        }
      ]
    })
    "ecs-exec" = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel", "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel"]
          Resource = "*"
        }
      ]
    })
  }

  task_log_groups = {
    "/ecs/maven/dofs" = {
      retention_in_days = 30
    }
    "/ecs/maven/shortenurl" = {
      retention_in_days = 30
    }
  }

  task_definitions = {
    "dofs" = {
      family                   = "maven-dofs"
      cpu                      = "512"
      memory                   = "1024"
      requires_compatibilities = ["FARGATE"]
      container_definitions_json = jsonencode([
        {
          name      = "dofs"
          image     = "${module.ecr.repository_urls["maven-dofs"]}:latest"
          essential = true
          portMappings = [
            {
              name          = "dofs-http"
              containerPort = 80
              protocol      = "tcp"
            }
          ]
          environment = [] # TBD (Kalbe) - e.g. { name = "DB_HOST", value = module.aurora.cluster_endpoint }
          secrets     = [] # TBD (Kalbe) - e.g. { name = "DB_PASSWORD", valueFrom = "${module.secrets.secret_arns["mavendb"]}:password::" }
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-group         = "/ecs/maven/dofs"
              awslogs-region        = var.region
              awslogs-stream-prefix = "app"
            }
          }
        }
      ])

      runtime_platform = {
        operating_system_family = "LINUX"
        cpu_architecture        = "X86_64" # TBD (Kalbe) - X86_64 or ARM64
      }
    }
    "shortenurl" = {
      family                   = "maven-shortenurl"
      cpu                      = "512"
      memory                   = "1024"
      requires_compatibilities = ["FARGATE"]
      container_definitions_json = jsonencode([
        {
          name      = "shortenurl"
          image     = "${module.ecr.repository_urls["maven-shortenurl"]}:latest"
          essential = true
          portMappings = [
            {
              name          = "shortenurl-http"
              containerPort = 80
              protocol      = "tcp"
            }
          ]
          environment = [] # TBD (Kalbe) - e.g. { name = "DB_HOST", value = module.aurora.cluster_endpoint }
          secrets     = [] # TBD (Kalbe) - e.g. { name = "DB_PASSWORD", valueFrom = "${module.secrets.secret_arns["shortendb"]}:password::" }
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-group         = "/ecs/maven/shortenurl"
              awslogs-region        = var.region
              awslogs-stream-prefix = "app"
            }
          }
        }
      ])

      runtime_platform = {
        operating_system_family = "LINUX"
        cpu_architecture        = "X86_64" # TBD (Kalbe) - X86_64 or ARM64
      }
    }
  }

  services = {
    "dofs" = {
      name                       = "maven-dofs"
      task_definition_key        = "dofs"
      desired_count              = 2
      deployment_controller_type = "CODE_DEPLOY"
      enable_execute_command     = true
      propagate_tags             = "SERVICE"

      health_check_grace_period_seconds = 60

      launch_type = "FARGATE"

      network_configuration = {
        subnets          = module.vpc.private_app_subnet_ids
        security_groups  = [module.sg_ecs.security_group_id]
        assign_public_ip = false
      }

      load_balancers = [
        {
          target_group_arn = module.alb_internal.target_group_arns["dofs-blue"]
          container_name   = "dofs"
          container_port   = 80
        }
      ]

      autoscaling = {
        min_capacity = 2
        max_capacity = 20

        policies = { for p, v in {
          "cpu" = {
            predefined_metric_type = "ECSServiceAverageCPUUtilization"
            target_value           = 70
            scale_out_cooldown     = 60
            scale_in_cooldown      = 300
          }
          "memory" = {
            predefined_metric_type = "ECSServiceAverageMemoryUtilization"
            target_value           = 80
            scale_out_cooldown     = 60
            scale_in_cooldown      = 300
          }
          "alb-requests" = {
            predefined_metric_type = "ALBRequestCountPerTarget"
            target_value           = 500
            resource_label         = "${module.alb_internal.lb_arn_suffix}/${module.alb_internal.target_group_arn_suffixes["dofs-blue"]}"
            scale_out_cooldown     = 60
            scale_in_cooldown      = 300
          }
        } : p => v if v.target_value != null }
      }
    }
    "shortenurl" = {
      name                       = "maven-shortenurl"
      task_definition_key        = "shortenurl"
      desired_count              = 2
      deployment_controller_type = "CODE_DEPLOY"
      enable_execute_command     = true
      propagate_tags             = "SERVICE"

      health_check_grace_period_seconds = 60

      launch_type = "FARGATE"

      network_configuration = {
        subnets          = module.vpc.private_app_subnet_ids
        security_groups  = [module.sg_ecs.security_group_id]
        assign_public_ip = false
      }

      load_balancers = [
        {
          target_group_arn = module.alb_internal.target_group_arns["shortenurl-blue"]
          container_name   = "shortenurl"
          container_port   = 80
        }
      ]

      autoscaling = {
        min_capacity = 2
        max_capacity = 20

        policies = { for p, v in {
          "cpu" = {
            predefined_metric_type = "ECSServiceAverageCPUUtilization"
            target_value           = 70
            scale_out_cooldown     = 60
            scale_in_cooldown      = 300
          }
          "memory" = {
            predefined_metric_type = "ECSServiceAverageMemoryUtilization"
            target_value           = 80
            scale_out_cooldown     = 60
            scale_in_cooldown      = 300
          }
          "alb-requests" = {
            predefined_metric_type = "ALBRequestCountPerTarget"
            target_value           = 500
            resource_label         = "${module.alb_internal.lb_arn_suffix}/${module.alb_internal.target_group_arn_suffixes["shortenurl-blue"]}"
            scale_out_cooldown     = 60
            scale_in_cooldown      = 300
          }
        } : p => v if v.target_value != null }
      }
    }
  }

  tags = {
    "Resource" = "ECS"
  }
}

# Cognito User Pool (OAuth2 client_credentials for external systems)
module "cognito" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-cognito-user-pool-v6?ref=main"

  name                = "shpdev-maven-userpool"
  user_pool_tier      = "LITE"
  deletion_protection = "ACTIVE"

  create_domain = true
  domain        = "shpdev-maven" # Domain prefix, must be unique in the Region

  resource_servers = {
    "shpdevmaven-api" = {
      identifier = "shpdevmaven-api"
      name       = "shpdevmaven-api"
      scopes     = {} # TBD (Kalbe, DDD T11/T12) - e.g. "dofs.write" = "Submit DoFS claims"
    }
  }

  clients = {
    for k, scopes in {
      "kartini"  = [] # TBD (DDD T13) - allowed scopes, e.g. ["shpdevmaven-api/dofs.write"]
      "kpoin"    = [] # TBD (DDD T13) - allowed scopes
      "app"      = [] # TBD (DDD T13) - allowed scopes
      "loadtest" = [] # TBD (DDD T13) - same scopes as the endpoints under test
      } : k => {
      name                                 = "shpdev-maven-${k}"
      generate_secret                      = true
      allowed_oauth_flows_user_pool_client = length(scopes) > 0
      allowed_oauth_flows                  = length(scopes) > 0 ? ["client_credentials"] : []
      allowed_oauth_scopes                 = scopes
      explicit_auth_flows                  = ["ALLOW_REFRESH_TOKEN_AUTH"]
      supported_identity_providers         = ["COGNITO"]
      access_token_validity                = 60
      enable_token_revocation              = true

      token_validity_units = {
        access_token = "minutes"
      }
    }
  }

  tags = {
    "Resource" = "Cognito"
  }
}

# API Gateway REST API
module "api_gateway" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-api-gateway-rest-v6?ref=main"

  name          = "shpdev-maven-api"
  description   = "Maven DoFS REST API"
  endpoint_type = "REGIONAL"

  create_vpc_link_v2             = true
  vpc_link_v2_subnet_ids         = module.vpc.private_app_subnet_ids
  vpc_link_v2_security_group_ids = [module.sg_vpc_link.security_group_id]

  authorizers = {
    "cognito" = {
      name          = "shpdev-maven-cognito-authorizer"
      type          = "COGNITO_USER_POOLS"
      provider_arns = [module.cognito.user_pool_arn]
    }
  }

  methods = {
    "dofs-root" = {
      path                 = "/dofs" # TBD (Kalbe, DDD T11)
      http_method          = "ANY"
      authorization        = "COGNITO_USER_POOLS"
      authorizer_key       = "cognito"
      authorization_scopes = null # TBD (DDD T11) - e.g. ["shpdevmaven-api/dofs.write"]
      api_key_required     = true

      integration = {
        type                    = "HTTP_PROXY"
        integration_http_method = "ANY"
        vpc_link                = "v2"
        integration_target      = module.alb_internal.lb_arn
        uri                     = "https://shpdev-maven-alb.kalbenutritionals.web.id:8443/" # Hostname covered by the ACM certificate; Kalbe DNS record only needed for on-premises access
        timeout_milliseconds    = 29000
      }
    }
    "dofs-proxy" = {
      path                 = "/dofs/{proxy+}" # TBD (Kalbe, DDD T11)
      http_method          = "ANY"
      authorization        = "COGNITO_USER_POOLS"
      authorizer_key       = "cognito"
      authorization_scopes = null # TBD (DDD T11) - e.g. ["shpdevmaven-api/dofs.write"]
      api_key_required     = true
      request_parameters   = { "method.request.path.proxy" = true }

      integration = {
        type                    = "HTTP_PROXY"
        integration_http_method = "ANY"
        vpc_link                = "v2"
        integration_target      = module.alb_internal.lb_arn
        uri                     = "https://shpdev-maven-alb.kalbenutritionals.web.id:8443/{proxy}"
        request_parameters      = { "integration.request.path.proxy" = "method.request.path.proxy" }
        timeout_milliseconds    = 29000
      }
    }
    "shortenurl-root" = {
      path                 = "/shortenurl" # TBD (Kalbe, DDD T11)
      http_method          = "ANY"
      authorization        = "COGNITO_USER_POOLS"
      authorizer_key       = "cognito"
      authorization_scopes = null # TBD (DDD T11) - e.g. ["shpdevmaven-api/url.write"]
      api_key_required     = true

      integration = {
        type                    = "HTTP_PROXY"
        integration_http_method = "ANY"
        vpc_link                = "v2"
        integration_target      = module.alb_internal.lb_arn
        uri                     = "https://shpdev-maven-alb.kalbenutritionals.web.id:8444/" # Hostname covered by the ACM certificate; Kalbe DNS record only needed for on-premises access
        timeout_milliseconds    = 29000
      }
    }
    "shortenurl-proxy" = {
      path                 = "/shortenurl/{proxy+}" # TBD (Kalbe, DDD T11)
      http_method          = "ANY"
      authorization        = "COGNITO_USER_POOLS"
      authorizer_key       = "cognito"
      authorization_scopes = null # TBD (DDD T11) - e.g. ["shpdevmaven-api/url.write"]
      api_key_required     = true
      request_parameters   = { "method.request.path.proxy" = true }

      integration = {
        type                    = "HTTP_PROXY"
        integration_http_method = "ANY"
        vpc_link                = "v2"
        integration_target      = module.alb_internal.lb_arn
        uri                     = "https://shpdev-maven-alb.kalbenutritionals.web.id:8444/{proxy}"
        request_parameters      = { "integration.request.path.proxy" = "method.request.path.proxy" }
        timeout_milliseconds    = 29000
      }
    }
  }

  create_cloudwatch_role = true

  custom_domain = {
    domain_name     = "api-mavendofs.kalbenutritionals.web.id"
    endpoint_type   = "REGIONAL"
    certificate_arn = module.acm_kalbe.certificate_arn
    security_policy = "TLS_1_2"

    base_path_mappings = {
      "main" = {
        stage_key = "main"
      }
    }
  }

  stages = {
    "main" = {
      stage_name           = "poc"
      xray_tracing_enabled = true

      access_log = {
        create_log_group  = true
        log_group_name    = "/aws/apigateway/shpdev-maven-access"
        retention_in_days = 30
        format = jsonencode({
          requestId          = "$context.requestId"
          ip                 = "$context.identity.sourceIp"
          requestTime        = "$context.requestTime"
          httpMethod         = "$context.httpMethod"
          resourcePath       = "$context.resourcePath"
          status             = "$context.status"
          responseLength     = "$context.responseLength"
          integrationLatency = "$context.integration.latency"
          responseLatency    = "$context.responseLatency"
          clientId           = "$context.authorizer.claims.client_id"
          apiKeyId           = "$context.identity.apiKeyId"
        })
      }

      method_settings = {
        "*/*" = {
          metrics_enabled        = true
          logging_level          = "ERROR"
          throttling_burst_limit = null # TBD (Kalbe, DDD T14) - stage-wide burst
          throttling_rate_limit  = null # TBD (Kalbe, DDD T14) - stage-wide requests per second
        }
      }
    }
  }

  api_keys = {
    "kartini" = {
      name = "shpdev-maven-key-kartini"
    }
    "kpoin" = {
      name = "shpdev-maven-key-kpoin"
    }
    "app" = {
      name = "shpdev-maven-key-app"
    }
    "loadtest" = {
      name = "shpdev-maven-key-loadtest"
    }
  }

  usage_plans = {
    "kartini" = {
      name              = "shpdev-maven-plan-kartini"
      stages            = [{ stage_key = "main" }]
      throttle_settings = null # TBD (DDD T15) - { rate_limit = <rps>, burst_limit = <burst> }
      quota_settings    = null # TBD (DDD T15) - { limit = <requests>, period = "DAY" }
      api_key_keys      = ["kartini"]
    }
    "kpoin" = {
      name              = "shpdev-maven-plan-kpoin"
      stages            = [{ stage_key = "main" }]
      throttle_settings = null # TBD (DDD T15) - { rate_limit = <rps>, burst_limit = <burst> }
      quota_settings    = null # TBD (DDD T15) - { limit = <requests>, period = "DAY" }
      api_key_keys      = ["kpoin"]
    }
    "app" = {
      name              = "shpdev-maven-plan-app"
      stages            = [{ stage_key = "main" }]
      throttle_settings = null # TBD (DDD T15) - { rate_limit = <rps>, burst_limit = <burst> }
      quota_settings    = null # TBD (DDD T15) - { limit = <requests>, period = "DAY" }
      api_key_keys      = ["app"]
    }
    "loadtest" = {
      name              = "shpdev-maven-plan-loadtest"
      stages            = [{ stage_key = "main" }]
      throttle_settings = null # TBD - load test target
      quota_settings    = null
      api_key_keys      = ["loadtest"]
    }
  }

  tags = {
    "Resource" = "APIGateway"
  }
}

# WAF - API Gateway
module "waf_api" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-waf?ref=main"

  name        = "shpdev-maven-waf"
  description = "Web Application Firewall for the Maven REST API"
  scope       = "REGIONAL"
  metric_name = "shpdev-maven-waf"

  default_action = "allow"

  aws_managed_rule_groups = {
    "ip-reputation" = {
      name                    = "AWSManagedRulesAmazonIpReputationList"
      priority                = 1
      managed_rule_group_name = "AWSManagedRulesAmazonIpReputationList"
      override_action         = "none"
      metric_name             = "shpdev-maven-waf-ip-reputation"
    }
    "common-rule-set" = {
      name                    = "AWSManagedRulesCommonRuleSet"
      priority                = 2
      managed_rule_group_name = "AWSManagedRulesCommonRuleSet"
      override_action         = "none"
      metric_name             = "shpdev-maven-waf-common"
    }
    "known-bad-inputs" = {
      name                    = "AWSManagedRulesKnownBadInputsRuleSet"
      priority                = 3
      managed_rule_group_name = "AWSManagedRulesKnownBadInputsRuleSet"
      override_action         = "none"
      metric_name             = "shpdev-maven-waf-bad-inputs"
    }
  }

  create_web_acl_association = true
  association_resource_arn   = module.api_gateway.stage_arns["main"]

  enable_logging        = true
  create_log_group      = true
  log_group_name        = "aws-waf-logs-shpdev-maven"
  log_retention_in_days = 30

  cloudwatch_metrics_enabled = true
  sampled_requests_enabled   = true

  tags = {
    "Resource" = "WAF"
  }
}

# CodeBuild - one project per service (.NET build, test, push to ECR)
module "codebuild" {
  source   = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-codebuild-v6?ref=main"
  for_each = toset(["dofs", "shortenurl"])

  name        = "shpdev-maven-${each.key}-build"
  description = "Build, test and push ${each.key} to ECR"

  source_config = {
    type     = "S3"
    location = "${module.s3_cicd.bucket_id}/${each.key}/source.zip"
  }

  environment = {
    compute_type    = "BUILD_GENERAL1_SMALL"
    type            = "LINUX_CONTAINER"                               # ARM_CONTAINER for ARM64 images
    image           = "aws/codebuild/amazonlinux-x86_64-standard:5.0" # aws/codebuild/amazonlinux-aarch64-standard:3.0 for ARM64 images
    privileged_mode = true

    environment_variables = [
      { name = "AWS_ACCOUNT_ID", value = "908027374739" },
      { name = "ECR_REPOSITORY_URI", value = module.ecr.repository_urls["maven-${each.key}"] },
      { name = "CONTAINER_NAME", value = each.key },
      { name = "ARTIFACT_BUCKET", value = module.s3_cicd.bucket_id }
    ]
  }

  encryption_key = module.kms_cmk.kms_key_arn

  service_role_s3_bucket_arns      = [module.s3_cicd.bucket_arn]
  service_role_ecr_repository_arns = [module.ecr.repository_arns["maven-${each.key}"]]
  service_role_kms_key_arns        = [module.kms_cmk.kms_key_arn]

  log_group_retention_in_days = 30

  tags = {
    "Resource" = "CodeBuild"
  }
}

# CodeDeploy - ECS blue/green
module "codedeploy" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-codedeploy-v6?ref=main"

  application_name = "shpdev-maven-ecs"
  compute_platform = "ECS"

  deployment_groups = {
    "dofs" = {
      name                   = "maven-dofs-dg"
      deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

      blue_green = {
        deployment_ready_action_on_timeout = "CONTINUE_DEPLOYMENT"
        terminate_blue_action              = "TERMINATE"
        termination_wait_time_in_minutes   = 5 # Time to keep the old task set for rollback
      }

      ecs_services = [
        {
          cluster_name = module.ecs.cluster_name
          service_name = module.ecs.service_names["dofs"]
        }
      ]

      load_balancer_info = {
        target_group_pair = {
          target_group_names = [
            module.alb_internal.target_group_names["dofs-blue"],
            module.alb_internal.target_group_names["dofs-green"]
          ]
          prod_listener_arns = [module.alb_internal.listener_arns["dofs"]]
          test_listener_arns = [module.alb_internal.listener_arns["dofs-test"]]
        }
      }

      auto_rollback = {
        enabled = true
        events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
      }

      alarm_configuration = {
        enabled = true
        alarms = [
          module.cloudwatch_alarms.metric_alarm_names["dofs-unhealthy-hosts-blue"],
          module.cloudwatch_alarms.metric_alarm_names["dofs-unhealthy-hosts-green"]
        ]
      }
    }
    "shortenurl" = {
      name                   = "maven-shortenurl-dg"
      deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

      blue_green = {
        deployment_ready_action_on_timeout = "CONTINUE_DEPLOYMENT"
        terminate_blue_action              = "TERMINATE"
        termination_wait_time_in_minutes   = 5 # Time to keep the old task set for rollback
      }

      ecs_services = [
        {
          cluster_name = module.ecs.cluster_name
          service_name = module.ecs.service_names["shortenurl"]
        }
      ]

      load_balancer_info = {
        target_group_pair = {
          target_group_names = [
            module.alb_internal.target_group_names["shortenurl-blue"],
            module.alb_internal.target_group_names["shortenurl-green"]
          ]
          prod_listener_arns = [module.alb_internal.listener_arns["shortenurl"]]
          test_listener_arns = [module.alb_internal.listener_arns["shortenurl-test"]]
        }
      }

      auto_rollback = {
        enabled = true
        events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
      }

      alarm_configuration = {
        enabled = true
        alarms = [
          module.cloudwatch_alarms.metric_alarm_names["shortenurl-unhealthy-hosts-blue"],
          module.cloudwatch_alarms.metric_alarm_names["shortenurl-unhealthy-hosts-green"]
        ]
      }
    }
  }

  service_role_inline_policies = {
    "pass-ecs-task-roles" = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["iam:PassRole"]
          Resource = [module.ecs.task_execution_role_arn, module.ecs.task_role_arn]
        },
        {
          Effect   = "Allow"
          Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
          Resource = [module.kms_cmk.kms_key_arn]
        }
      ]
    })
  }

  tags = {
    "Resource" = "CodeDeploy"
  }
}

# AMI - DataSync Agent (latest)
data "aws_ssm_parameter" "datasync_ami" {
  count = var.create_datasync_agent_instance ? 1 : 0
  name  = "/aws/service/datasync/ami"
}

# EC2 Instances - k6 Load Test and DataSync Agent (toggle: create_loadtest_instance, create_datasync_agent_instance)
module "ec2_tools" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-ec2-instances?ref=main"

  iam_role_name             = "shpdev-maven-ec2-instance-role"
  iam_instance_profile_name = "shpdev-maven-ec2-instance-profile"

  instances = merge(
    { for k, v in {
      "loadtest" = {
        ami_id             = data.aws_ssm_parameter.al2023_x86_64.insecure_value
        instance_type      = "c5.xlarge" # TBD (Kalbe) - size to the load test target
        subnet_id          = module.vpc.private_app_subnet_ids[0]
        security_group_ids = [module.sg_loadtest.security_group_id]

        root_block_device = {
          volume_type = "gp3"
          volume_size = 20
          encrypted   = true
          kms_key_id  = module.kms_cmk.kms_key_arn
        }

        tags = {
          "Name"    = "shpdev-maven-loadtest-k6"
          "Purpose" = "k6 Load Test (temporary)"
        }
      }
    } : k => v if var.create_loadtest_instance },
    { for k, v in {
      "datasync-agent" = {
        ami_id             = one(data.aws_ssm_parameter.datasync_ami[*].insecure_value)
        instance_type      = "m5.2xlarge" # Minimum size for the DataSync agent
        subnet_id          = module.vpc.private_app_subnet_ids[0]
        security_group_ids = [module.sg_datasync_agent.security_group_id]

        root_block_device = {
          volume_type = "gp3"
          volume_size = 80
          encrypted   = true
          kms_key_id  = module.kms_cmk.kms_key_arn
        }

        tags = {
          "Name"    = "shpdev-maven-datasync-agent"
          "Purpose" = "DataSync Agent (NAS to S3)"
        }
      }
    } : k => v if var.create_datasync_agent_instance }
  )

  tags = {
    "Resource" = "EC2"
  }
}

# DataSync - NAS to S3 (toggle: create_datasync_agent_instance, datasync_agent_activation_key)
module "datasync" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-datasync?ref=main"

  name_prefix = "shpdev-maven"

  agents = { for k, v in {
    "ec2" = {
      name                = "shpdev-maven-datasync-agent"
      activation_key      = var.datasync_agent_activation_key
      vpc_endpoint_id     = try(module.vpce_datasync[0].endpoint_ids["datasync"], null)
      subnet_arns         = ["arn:aws:ec2:${var.region}:908027374739:subnet/${module.vpc.private_app_subnet_ids[0]}"]
      security_group_arns = ["arn:aws:ec2:${var.region}:908027374739:security-group/${try(module.vpce_datasync[0].security_group_id, "")}"]
    }
  } : k => v if var.datasync_agent_activation_key != null && var.create_datasync_agent_instance }

  s3_locations = {
    "assets" = {
      s3_bucket_arn = module.s3_assets.bucket_arn
      subdirectory  = "/"
      access_mode   = "write"
      kms_key_arns  = [module.kms_cmk.kms_key_arn]
    }
  }

  smb_locations = { for k, v in {
    "nas" = {
      server_hostname = "10.104.1.170"
      subdirectory    = "/knapps/dev/maven"
      user            = ""   # TBD (Kalbe) - SMB user with read access to the share
      domain          = null # TBD (Kalbe) - Windows domain of the SMB user, if any
      password        = var.datasync_smb_password
      agent_keys      = ["ec2"]
    }
  } : k => v if var.datasync_agent_activation_key != null && var.create_datasync_agent_instance }

  tasks = { for k, v in {
    "nas-to-s3" = {
      name                     = "shpdev-maven-nas-to-s3"
      source_location_key      = "smb.nas"
      destination_location_key = "s3.assets"

      cloudwatch_log_retention_in_days = 30

      options = {
        bytes_per_second = -1 # TBD (Kalbe, DDD T22) - bandwidth limit in bytes per second (Mbps x 125000), -1 is unlimited
      }
    }
  } : k => v if var.datasync_agent_activation_key != null && var.create_datasync_agent_instance }

  tags = {
    "Resource" = "DataSync"
  }
}
