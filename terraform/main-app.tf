locals {
  ecs_cluster_name     = "maven-cluster"
  ecs_cpu_architecture = "X86_64" # TBD (Kalbe) - X86_64 or ARM64, architecture of the .NET container images

  # ECS services; third service (maven-backend-3) is TBD (Kalbe, DDD T17)
  ecs_services = {
    "dofs" = {
      container_port             = 8080 # TBD (Kalbe, DDD T17)
      listener_port              = 8081
      test_listener_port         = 9081
      health_check_path          = "/healthcheck" # TBD (Kalbe)
      cpu                        = 512
      memory                     = 1024
      desired_count              = 2
      min_capacity               = 2
      max_capacity               = 20
      request_count_per_target   = null # TBD (DDD T18) - ALBRequestCountPerTarget target; null skips the policy
      cpu_target_utilization     = 70
      memory_target_utilization  = 80
      health_check_grace_period  = 60
      deregistration_delay       = 30
      image_tag                  = "latest"
      api_base_path              = "dofs" # TBD (Kalbe, DDD T11)
      environment                = {}     # TBD (Kalbe) - env name = value; tokens {{aurora_endpoint}}, {{valkey_endpoint}}, {{valkey_port}}, {{assets_bucket}}, {{region}}
      secrets                    = {}     # TBD (Kalbe) - env name = "<secret>:<json key>", secret is aurora-master, shortendb, mavendb, valkey or cognito-app
      enable_application_signals = false
    }
    "shortenurl" = {
      container_port             = 8080 # TBD (Kalbe, DDD T17)
      listener_port              = 8082
      test_listener_port         = 9082
      health_check_path          = "/healthcheck" # TBD (Kalbe)
      cpu                        = 512
      memory                     = 1024
      desired_count              = 2
      min_capacity               = 2
      max_capacity               = 20
      request_count_per_target   = null # TBD (DDD T18) - ALBRequestCountPerTarget target; null skips the policy
      cpu_target_utilization     = 70
      memory_target_utilization  = 80
      health_check_grace_period  = 60
      deregistration_delay       = 30
      image_tag                  = "latest"
      api_base_path              = "shortenurl" # TBD (Kalbe, DDD T11)
      environment                = {}           # TBD (Kalbe)
      secrets                    = {}           # TBD (Kalbe)
      enable_application_signals = false
    }
  }

  # Aurora application users (DDD T7), one <db>/aurora secret each
  aurora_app_users = {
    "shortendb" = "" # TBD (Kalbe) - application username for ShortenDB
    "mavendb"   = "" # TBD (Kalbe) - application username for MavenDB
  }

  # Cognito resource server scopes (DDD T11/T12), scope name = description
  cognito_scopes = {} # TBD (Kalbe) - e.g. "dofs.write" = "Submit DoFS claims"

  # API clients (DDD T13/T15); empty scopes create the client without OAuth flow, null limits skip throttle/quota
  api_clients = {
    "kartini" = {
      scopes                = [] # TBD (DDD T13)
      access_token_validity = 60
      rate_limit            = null # TBD (DDD T15) - requests per second
      burst_limit           = null # TBD (DDD T15)
      quota_per_day         = null # TBD (DDD T15)
    }
    "kpoin" = {
      scopes                = [] # TBD (DDD T13)
      access_token_validity = 60
      rate_limit            = null # TBD (DDD T15) - requests per second
      burst_limit           = null # TBD (DDD T15)
      quota_per_day         = null # TBD (DDD T15)
    }
    "app" = {
      scopes                = [] # TBD (DDD T13)
      access_token_validity = 60
      rate_limit            = null # TBD (DDD T15) - requests per second
      burst_limit           = null # TBD (DDD T15)
      quota_per_day         = null # TBD (DDD T15)
    }
    "loadtest" = {
      scopes                = [] # TBD (DDD T13) - same scopes as the endpoints under test
      access_token_validity = 60
      rate_limit            = null # TBD - load test target
      burst_limit           = null # TBD - load test target
      quota_per_day         = null
    }
  }

  services = {
    for k, s in local.ecs_services : k => merge(s, {
      name           = "maven-${k}"
      repository     = "maven-${k}"
      log_group_name = "/ecs/maven/${k}"
    })
  }

  otel_volume_name = "opentelemetry-auto-instrumentation"
  otel_arch_dir    = local.ecs_cpu_architecture == "ARM64" ? "linux-arm64" : "linux-x64"

  env_tokens = {
    aurora_endpoint        = module.aurora.cluster_endpoint
    aurora_reader_endpoint = module.aurora.cluster_reader_endpoint
    aurora_port            = tostring(module.aurora.cluster_port)
    valkey_endpoint        = module.valkey.primary_endpoint_address
    valkey_port            = "6379"
    assets_bucket          = module.s3_assets.bucket_id
    region                 = var.region
  }

  secret_refs = merge(
    {
      "aurora-master" = module.aurora.cluster_master_user_secret_arn
      "valkey"        = module.secrets.secret_arns["valkey"]
    },
    { for db in keys(local.aurora_app_users) : db => module.secrets.secret_arns[db] },
    { for k, v in { "cognito-app" = try(module.secrets.secret_arns["cognito-app"], null) } : k => v if contains(keys(local.api_clients), "app") }
  )

  api_scopes = [for scope in keys(local.cognito_scopes) : "maven-api/${scope}"]

  container_definitions = {
    for k, s in local.services : k => concat(
      [
        merge({
          name      = k
          image     = "${module.ecr.repository_urls[s.repository]}:${s.image_tag}"
          essential = true
          portMappings = [
            {
              name          = "${k}-http"
              containerPort = s.container_port
              protocol      = "tcp"
            }
          ]
          environment = concat(
            [
              for n, v in s.environment : {
                name = n
                value = replace(replace(replace(replace(replace(replace(replace(v,
                  "{{aurora_endpoint}}", local.env_tokens.aurora_endpoint),
                  "{{aurora_reader_endpoint}}", local.env_tokens.aurora_reader_endpoint),
                  "{{aurora_port}}", local.env_tokens.aurora_port),
                  "{{valkey_endpoint}}", local.env_tokens.valkey_endpoint),
                  "{{valkey_port}}", local.env_tokens.valkey_port),
                  "{{assets_bucket}}", local.env_tokens.assets_bucket),
                "{{region}}", local.env_tokens.region)
              }
            ],
            [for e in [
              { name = "OTEL_RESOURCE_ATTRIBUTES", value = "aws.log.group.names=${s.log_group_name},service.name=${s.name}" },
              { name = "CORECLR_ENABLE_PROFILING", value = "1" },
              { name = "CORECLR_PROFILER", value = "{918728DD-259F-4A6A-AC2B-B85E1B658318}" },
              { name = "CORECLR_PROFILER_PATH", value = "/otel-auto-instrumentation/${local.otel_arch_dir}/OpenTelemetry.AutoInstrumentation.Native.so" },
              { name = "DOTNET_ADDITIONAL_DEPS", value = "/otel-auto-instrumentation/AdditionalDeps" },
              { name = "DOTNET_SHARED_STORE", value = "/otel-auto-instrumentation/store" },
              { name = "DOTNET_STARTUP_HOOKS", value = "/otel-auto-instrumentation/net/OpenTelemetry.AutoInstrumentation.StartupHook.dll" },
              { name = "OTEL_DOTNET_AUTO_HOME", value = "/otel-auto-instrumentation" },
              { name = "OTEL_DOTNET_AUTO_PLUGINS", value = "AWS.Distro.OpenTelemetry.AutoInstrumentation.Plugin, AWS.Distro.OpenTelemetry.AutoInstrumentation" },
              { name = "OTEL_LOGS_EXPORTER", value = "none" },
              { name = "OTEL_METRICS_EXPORTER", value = "none" },
              { name = "OTEL_EXPORTER_OTLP_PROTOCOL", value = "http/protobuf" },
              { name = "OTEL_AWS_APPLICATION_SIGNALS_ENABLED", value = "true" },
              { name = "OTEL_AWS_APPLICATION_SIGNALS_EXPORTER_ENDPOINT", value = "http://localhost:4316/v1/metrics" },
              { name = "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", value = "http://localhost:4316/v1/traces" },
              { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://localhost:4316" },
              { name = "OTEL_TRACES_SAMPLER", value = "xray" },
              { name = "OTEL_TRACES_SAMPLER_ARG", value = "endpoint=http://localhost:2000" },
              { name = "OTEL_PROPAGATORS", value = "tracecontext,baggage,b3,xray" }
            ] : e if s.enable_application_signals]
          )
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-group         = s.log_group_name
              awslogs-region        = var.region
              awslogs-stream-prefix = "app"
            }
          }
          },
          concat(
            [for x in [{
              secrets = [
                for n, ref in s.secrets : {
                  name      = n
                  valueFrom = "${local.secret_refs[split(":", ref)[0]]}:${split(":", ref)[1]}::"
                }
              ]
            }] : x if length(s.secrets) > 0],
            [for x in [{
              dependsOn   = [{ containerName = "init", condition = "SUCCESS" }]
              mountPoints = [{ sourceVolume = local.otel_volume_name, containerPath = "/otel-auto-instrumentation", readOnly = false }]
            }] : x if s.enable_application_signals]
          )...
        )
      ],
      [for c in [
        {
          name        = "init"
          image       = "public.ecr.aws/aws-observability/adot-autoinstrumentation-dotnet:vX.Y.Z" # TBD - pin the latest release tag before enabling Application Signals
          essential   = false
          command     = ["cp", "-a", "autoinstrumentation/.", "/otel-auto-instrumentation"]
          mountPoints = [{ sourceVolume = local.otel_volume_name, containerPath = "/otel-auto-instrumentation", readOnly = false }]
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-group         = s.log_group_name
              awslogs-region        = var.region
              awslogs-stream-prefix = "init"
            }
          }
        },
        {
          name      = "ecs-cwagent"
          image     = "public.ecr.aws/cloudwatch-agent/cloudwatch-agent:latest"
          essential = true
          environment = [
            {
              name = "CW_CONFIG_CONTENT"
              value = jsonencode({
                traces = { traces_collected = { application_signals = {} } }
                logs   = { metrics_collected = { application_signals = {} } }
              })
            }
          ]
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-group         = s.log_group_name
              awslogs-region        = var.region
              awslogs-stream-prefix = "cwagent"
            }
          }
        }
      ] : c if s.enable_application_signals]
    )
  }

  api_routes = merge([
    for k, s in local.services : {
      "${k}-root" = {
        path          = "/${s.api_base_path}"
        proxy         = false
        service_key   = k
        listener_port = s.listener_port
      }
      "${k}-proxy" = {
        path          = "/${s.api_base_path}/{proxy+}"
        proxy         = true
        service_key   = k
        listener_port = s.listener_port
      }
    } if s.api_base_path != null
  ]...)
}

# CMK
module "kms_cmk" {
  source = "../../Terraform-Module/aws-cmk-v6"

  description             = "KMS CMK for the Maven POC"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  key_name                = "cmk-maven-908027374739"
  key_alias               = "cmk-maven-908027374739"

  additional_service_principals = ["events.amazonaws.com", "cloudwatch.amazonaws.com"]

  tags = {
    "Resource" = "CMK"
  }
}

# IAM GROUPS
# Administrator
module "iam_group_administrator" {
  source = "../../Terraform-Module/aws-iam-user-group"

  group_name = "Administrator"

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

  users = {} # TBD (DDD T26) - user name = {}

  tags = {
    "Resource" = "IAM"
  }
}

# ReadOnly
module "iam_group_readonly" {
  source = "../../Terraform-Module/aws-iam-user-group"

  group_name = "ReadOnly"

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
    module.iam_group_administrator.customer_managed_policy_arns["Force_MFA"]
  ]

  users = {} # TBD (DDD T26) - user name = {}

  tags = {
    "Resource" = "IAM"
  }
}

# Secrets Manager (Aurora master credential is managed by RDS)
module "secrets" {
  source = "../../Terraform-Module/aws-secrets-manager-v6"

  kms_key_id              = module.kms_cmk.kms_key_arn
  recovery_window_in_days = 7

  secrets = merge(
    {
      for db, username in local.aurora_app_users : db => {
        name        = "${db}/aurora"
        description = "Aurora PostgreSQL application credential for ${db}"

        generate_random_password = {
          length  = 32
          special = false
        }
        generated_password_json_key = "password"
        secret_string_template = {
          username = username
          dbname   = db
          engine   = "postgres"
          host     = module.aurora.cluster_endpoint
          port     = tostring(module.aurora.cluster_port)
        }
      }
    },
    {
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
    },
    { for k, v in {
      "cognito-app" = {
        name        = "cognito/maven-app"
        description = "Cognito app client credential of the Maven application"
      }
    } : k => v if contains(keys(local.api_clients), "app") }
  )

  secret_values = { for k, v in {
    "cognito-app" = {
      secret_string = jsonencode({
        TOKEN_URL     = module.cognito.oauth2_token_url
        CLIENT_ID     = try(module.cognito.client_ids["app"], "")
        CLIENT_SECRET = try(module.cognito.client_secrets["app"], "")
      })
    }
  } : k => v if contains(keys(local.api_clients), "app") }

  tags = {
    "Resource" = "SecretsManager"
  }
}

# Aurora PostgreSQL Serverless v2
module "aurora" {
  source = "../../Terraform-Module/aws-rds-aurora-v6"

  cluster_identifier = "maven-db"
  engine             = "aurora-postgresql"
  engine_version     = null # TBD (Kalbe, DDD T19) - same or newer major version than on-premises PostgreSQL
  database_name      = null # TBD (Kalbe, DDD T19) - initial database name
  master_username    = "mavenadmin"

  manage_master_user_password   = true
  master_user_secret_kms_key_id = module.kms_cmk.kms_key_arn

  subnet_ids             = module.vpc.private_db_subnet_ids
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
  source = "../../Terraform-Module/aws-elasticache"

  name           = "maven-valkey"
  description    = "Maven cache (Valkey)"
  engine         = "valkey"
  engine_version = null # TBD (Kalbe, DDD T20) - null uses the latest version
  node_type      = "cache.m6g.large"

  subnet_ids         = module.vpc.private_db_subnet_ids
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
  name              = "/elasticache/maven-valkey/slow-log"
  retention_in_days = 30 # Slow log retention

  tags = {
    "Resource" = "CloudWatch"
  }
}

# S3 Bucket - Assets (NAS migration target)
module "s3_assets" {
  source = "../../Terraform-Module/aws-s3-bucket"

  bucket_name       = "maven-asset-908027374739"
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
  source = "../../Terraform-Module/aws-s3-bucket"

  bucket_name       = "maven-cicd-artifacts-908027374739"
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
  source = "../../Terraform-Module/aws-ecr-private-repository"

  repositories         = [for k, s in local.services : s.repository]
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

# Internal ALB
module "alb_internal" {
  source = "../../Terraform-Module/aws-load-balancer"

  name               = "maven-alb-internal"
  load_balancer_type = "application"
  internal           = true
  ip_address_type    = "ipv4"

  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.other_private_subnet_first_ids
  security_group_ids = [module.sg_alb.security_group_id]

  enable_deletion_protection = false
  drop_invalid_header_fields = true
  idle_timeout               = 60

  access_logs = {
    bucket  = module.s3_logs.bucket_id
    prefix  = "alb-internal"
    enabled = true
  }

  target_groups = merge([
    for k, s in local.services : {
      for color in ["blue", "green"] : "${k}-${color}" => {
        name                 = "tg-maven-${k}-${color}"
        port                 = s.container_port
        protocol             = "HTTP"
        target_type          = "ip"
        deregistration_delay = s.deregistration_delay

        health_check = {
          path     = s.health_check_path
          protocol = "HTTP"
          matcher  = "200"
          interval = 15
          timeout  = 5
        }
      }
    }
  ]...)

  listeners = merge(
    {
      for k, s in local.services : k => {
        port                          = s.listener_port
        protocol                      = "HTTP"
        action_type                   = "forward"
        target_group_key              = "${k}-blue"
        ignore_default_action_changes = true
      }
    },
    {
      for k, s in local.services : "${k}-test" => {
        port                          = s.test_listener_port
        protocol                      = "HTTP"
        action_type                   = "forward"
        target_group_key              = "${k}-green"
        ignore_default_action_changes = true
      } if s.test_listener_port != null
    }
  )

  tags = {
    "Resource" = "LoadBalancer"
  }
}

# ECS Cluster (Fargate)
module "ecs" {
  source = "../../Terraform-Module/aws-ecs"

  cluster_name       = local.ecs_cluster_name
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
          Effect   = "Allow"
          Action   = ["secretsmanager:GetSecretValue"]
          Resource = values(local.secret_refs)
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
    for k, s in local.services : s.log_group_name => {
      retention_in_days = 30
    }
  }

  task_definitions = {
    for k, s in local.services : k => {
      family                     = s.name
      cpu                        = tostring(s.cpu)
      memory                     = tostring(s.memory)
      requires_compatibilities   = ["FARGATE"]
      container_definitions_json = jsonencode(local.container_definitions[k])

      runtime_platform = {
        operating_system_family = "LINUX"
        cpu_architecture        = local.ecs_cpu_architecture
      }

      volumes = [for v in [{ name = local.otel_volume_name }] : v if s.enable_application_signals]
    }
  }

  services = {
    for k, s in local.services : k => {
      name                       = s.name
      task_definition_key        = k
      desired_count              = s.desired_count
      deployment_controller_type = "CODE_DEPLOY"
      enable_execute_command     = true
      propagate_tags             = "SERVICE"

      health_check_grace_period_seconds = s.health_check_grace_period

      launch_type = "FARGATE"

      network_configuration = {
        subnets          = module.vpc.private_app_subnet_ids
        security_groups  = [module.sg_ecs.security_group_id]
        assign_public_ip = false
      }

      load_balancers = [
        {
          target_group_arn = module.alb_internal.target_group_arns["${k}-blue"]
          container_name   = k
          container_port   = s.container_port
        }
      ]

      autoscaling = {
        min_capacity = s.min_capacity
        max_capacity = s.max_capacity

        policies = merge(
          {
            "cpu" = {
              predefined_metric_type = "ECSServiceAverageCPUUtilization"
              target_value           = s.cpu_target_utilization
              scale_out_cooldown     = 60
              scale_in_cooldown      = 120
            }
          },
          { for p, v in {
            "memory" = {
              predefined_metric_type = "ECSServiceAverageMemoryUtilization"
              target_value           = s.memory_target_utilization
              scale_out_cooldown     = 60
              scale_in_cooldown      = 120
            }
          } : p => v if s.memory_target_utilization != null },
          { for p, v in {
            "alb-requests" = {
              predefined_metric_type = "ALBRequestCountPerTarget"
              target_value           = s.request_count_per_target
              resource_label         = "${module.alb_internal.lb_arn_suffix}/${module.alb_internal.target_group_arn_suffixes["${k}-blue"]}"
              scale_out_cooldown     = 60
              scale_in_cooldown      = 120
            }
          } : p => v if s.request_count_per_target != null }
        )
      }
    }
  }

  tags = {
    "Resource" = "ECS"
  }
}

# Cognito User Pool (OAuth2 client_credentials for external systems)
module "cognito" {
  source = "../../Terraform-Module/aws-cognito-user-pool-v6"

  name                = "maven-userpool"
  user_pool_tier      = "LITE"
  deletion_protection = "ACTIVE"

  create_domain = true
  domain        = "maven" # Domain prefix, must be unique in the Region; replace if already taken

  resource_servers = {
    "maven-api" = {
      identifier = "maven-api"
      name       = "maven-api"
      scopes     = local.cognito_scopes
    }
  }

  clients = {
    for k, c in local.api_clients : k => {
      name                                 = "maven-${k}"
      generate_secret                      = true
      allowed_oauth_flows_user_pool_client = length(c.scopes) > 0
      allowed_oauth_flows                  = length(c.scopes) > 0 ? ["client_credentials"] : []
      allowed_oauth_scopes                 = [for scope in c.scopes : "maven-api/${scope}"]
      explicit_auth_flows                  = ["ALLOW_REFRESH_TOKEN_AUTH"]
      supported_identity_providers         = ["COGNITO"]
      access_token_validity                = c.access_token_validity
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
  source = "../../Terraform-Module/aws-api-gateway-rest-v6"

  name          = "maven-api"
  description   = "Maven DoFS REST API"
  endpoint_type = "REGIONAL"

  create_vpc_link_v2             = true
  vpc_link_v2_subnet_ids         = module.vpc.other_private_subnet_first_ids
  vpc_link_v2_security_group_ids = [module.sg_vpc_link.security_group_id]

  authorizers = {
    "cognito" = {
      name          = "maven-cognito-authorizer"
      type          = "COGNITO_USER_POOLS"
      provider_arns = [module.cognito.user_pool_arn]
    }
  }

  methods = {
    for k, r in local.api_routes : k => {
      path                 = r.path
      http_method          = "ANY"
      authorization        = "COGNITO_USER_POOLS"
      authorizer_key       = "cognito"
      authorization_scopes = length(local.api_scopes) > 0 ? local.api_scopes : null
      api_key_required     = true
      request_parameters   = r.proxy ? { "method.request.path.proxy" = true } : null

      integration = {
        type                    = "HTTP_PROXY"
        integration_http_method = "ANY"
        vpc_link                = "v2"
        integration_target      = module.alb_internal.lb_arn
        uri                     = r.proxy ? "http://${module.alb_internal.lb_dns_name}:${r.listener_port}/{proxy}" : "http://${module.alb_internal.lb_dns_name}:${r.listener_port}/"
        request_parameters      = r.proxy ? { "integration.request.path.proxy" = "method.request.path.proxy" } : null
        timeout_milliseconds    = 29000
      }
    }
  }

  create_cloudwatch_role = true

  stages = {
    "main" = {
      stage_name           = "poc"
      xray_tracing_enabled = true

      access_log = {
        create_log_group  = true
        log_group_name    = "/aws/apigateway/maven-access"
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
    for k, c in local.api_clients : k => {
      name = "maven-key-${k}"
    }
  }

  usage_plans = {
    for k, c in local.api_clients : k => {
      name = "maven-plan-${k}"
      stages = [
        {
          stage_key = "main"
        }
      ]
      throttle_settings = c.rate_limit != null || c.burst_limit != null ? {
        burst_limit = c.burst_limit
        rate_limit  = c.rate_limit
      } : null
      quota_settings = c.quota_per_day != null ? {
        limit  = c.quota_per_day
        period = "DAY"
      } : null
      api_key_keys = [k]
    }
  }

  tags = {
    "Resource" = "APIGateway"
  }
}

# WAF - API Gateway
module "waf_api" {
  source = "../../Terraform-Module/aws-waf"

  name        = "maven-api-waf"
  description = "Web Application Firewall for the Maven REST API"
  scope       = "REGIONAL"
  metric_name = "maven-api-waf"

  default_action = "allow"

  aws_managed_rule_groups = {
    "ip-reputation" = {
      name                    = "AWSManagedRulesAmazonIpReputationList"
      priority                = 1
      managed_rule_group_name = "AWSManagedRulesAmazonIpReputationList"
      override_action         = "none"
      metric_name             = "maven-waf-ip-reputation"
    }
    "common-rule-set" = {
      name                    = "AWSManagedRulesCommonRuleSet"
      priority                = 2
      managed_rule_group_name = "AWSManagedRulesCommonRuleSet"
      override_action         = "none"
      metric_name             = "maven-waf-common"
    }
    "known-bad-inputs" = {
      name                    = "AWSManagedRulesKnownBadInputsRuleSet"
      priority                = 3
      managed_rule_group_name = "AWSManagedRulesKnownBadInputsRuleSet"
      override_action         = "none"
      metric_name             = "maven-waf-bad-inputs"
    }
  }

  create_web_acl_association = true
  association_resource_arn   = module.api_gateway.stage_arns["main"]

  enable_logging        = true
  create_log_group      = true
  log_group_name        = "aws-waf-logs-maven"
  log_retention_in_days = 30

  cloudwatch_metrics_enabled = true
  sampled_requests_enabled   = true

  tags = {
    "Resource" = "WAF"
  }
}

# CodeBuild - one project per service (.NET build, test, push to ECR)
module "codebuild" {
  source   = "../../Terraform-Module/aws-codebuild-v6"
  for_each = local.services

  name        = "${each.value.name}-build"
  description = "Build, test and push ${each.key} to ECR"

  source_config = {
    type     = "S3"
    location = "${module.s3_cicd.bucket_id}/${each.key}/source.zip"
  }

  environment = {
    compute_type    = "BUILD_GENERAL1_SMALL"
    type            = local.ecs_cpu_architecture == "ARM64" ? "ARM_CONTAINER" : "LINUX_CONTAINER"
    image           = local.ecs_cpu_architecture == "ARM64" ? "aws/codebuild/amazonlinux-aarch64-standard:3.0" : "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    privileged_mode = true

    environment_variables = [
      { name = "AWS_ACCOUNT_ID", value = "908027374739" },
      { name = "ECR_REPOSITORY_URI", value = module.ecr.repository_urls[each.value.repository] },
      { name = "CONTAINER_NAME", value = each.key },
      { name = "ARTIFACT_BUCKET", value = module.s3_cicd.bucket_id }
    ]
  }

  encryption_key = module.kms_cmk.kms_key_arn

  service_role_s3_bucket_arns      = [module.s3_cicd.bucket_arn]
  service_role_ecr_repository_arns = [module.ecr.repository_arns[each.value.repository]]
  service_role_kms_key_arns        = [module.kms_cmk.kms_key_arn]

  log_group_retention_in_days = 30

  tags = {
    "Resource" = "CodeBuild"
  }
}

# CodeDeploy - ECS blue/green
module "codedeploy" {
  source = "../../Terraform-Module/aws-codedeploy-v6"

  application_name = "maven-ecs"
  compute_platform = "ECS"

  deployment_groups = {
    for k, s in local.services : k => {
      name                   = "${s.name}-dg"
      deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

      blue_green = {
        deployment_ready_action_on_timeout = "CONTINUE_DEPLOYMENT"
        terminate_blue_action              = "TERMINATE"
        termination_wait_time_in_minutes   = 5 # Time to keep the old task set for rollback
      }

      ecs_services = [
        {
          cluster_name = module.ecs.cluster_name
          service_name = module.ecs.service_names[k]
        }
      ]

      load_balancer_info = {
        target_group_pair = {
          target_group_names = [
            module.alb_internal.target_group_names["${k}-blue"],
            module.alb_internal.target_group_names["${k}-green"]
          ]
          prod_listener_arns = [module.alb_internal.listener_arns[k]]
          test_listener_arns = s.test_listener_port != null ? [module.alb_internal.listener_arns["${k}-test"]] : []
        }
      }

      auto_rollback = {
        enabled = true
        events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
      }

      alarm_configuration = {
        enabled = true
        alarms = [
          module.cloudwatch_alarms.metric_alarm_names["${k}-unhealthy-hosts-blue"],
          module.cloudwatch_alarms.metric_alarm_names["${k}-unhealthy-hosts-green"]
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
  source = "../../Terraform-Module/aws-ec2-instances"

  iam_role_name             = "maven-ec2-instance-role"
  iam_instance_profile_name = "maven-ec2-instance-profile"

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
          "Name"    = "maven-loadtest-k6"
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
          "Name"    = "maven-datasync-agent"
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
  source = "../../Terraform-Module/aws-datasync"

  name_prefix = "maven"

  agents = { for k, v in {
    "ec2" = {
      name                = "maven-datasync-agent"
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

  nfs_locations = { for k, v in {
    "nas" = {
      server_hostname = ""   # TBD (Kalbe, DDD T22) - NAS IP or hostname reachable over VPN
      subdirectory    = ""   # TBD (Kalbe, DDD T22) - NFS export path
      nfs_version     = null # TBD (Kalbe, DDD T22) - AUTOMATIC, NFS3, NFS4_0 or NFS4_1
      agent_keys      = ["ec2"]
    }
  } : k => v if var.datasync_agent_activation_key != null && var.create_datasync_agent_instance }

  tasks = { for k, v in {
    "nas-to-s3" = {
      name                     = "maven-nas-to-s3"
      source_location_key      = "nfs.nas"
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
