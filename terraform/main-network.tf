locals {
  onprem_cidrs         = [] # TBD (Kalbe, DDD T2) - on-premises CIDRs behind the VPN
  migration_host_cidrs = [] # TBD (Kalbe, DDD T6) - Kalbe migration host IP as /32
  customer_gateway_ip  = "" # TBD (Kalbe, DDD T2) - static public IP of the Kalbe VPN device; empty skips the VPN

  onprem_access_enabled = length(local.onprem_cidrs) > 0
  migration_access      = length(local.migration_host_cidrs) > 0
  vpn_enabled           = local.customer_gateway_ip != ""
}

# VPC
module "vpc" {
  source = "../../Terraform-Module/aws-vpc"

  vpc_name = "maven-vpc"
  vpc_cidr = "10.100.0.0/16"
  azs      = ["ap-southeast-3a", "ap-southeast-3b", "ap-southeast-3c"]

  public_subnets      = ["10.100.0.0/24", "10.100.1.0/24", "10.100.2.0/24"]
  public_subnet_names = ["public-subnet-3a", "public-subnet-3b", "public-subnet-3c"]
  public_subnet_azs   = ["ap-southeast-3a", "ap-southeast-3b", "ap-southeast-3c"]

  other_private_subnets_first      = ["10.100.10.0/24", "10.100.11.0/24", "10.100.12.0/24"]
  other_private_subnet_first_names = ["private-subnet-lb-3a", "private-subnet-lb-3b", "private-subnet-lb-3c"]
  other_private_subnet_first_azs   = ["ap-southeast-3a", "ap-southeast-3b", "ap-southeast-3c"]

  private_app_subnets      = ["10.100.20.0/22", "10.100.24.0/22", "10.100.28.0/22"]
  private_app_subnet_names = ["private-subnet-app-3a", "private-subnet-app-3b", "private-subnet-app-3c"]
  private_app_subnet_azs   = ["ap-southeast-3a", "ap-southeast-3b", "ap-southeast-3c"]

  private_db_subnets      = ["10.100.40.0/24", "10.100.41.0/24", "10.100.42.0/24"]
  private_db_subnet_names = ["private-subnet-data-3a", "private-subnet-data-3b", "private-subnet-data-3c"]
  private_db_subnet_azs   = ["ap-southeast-3a", "ap-southeast-3b", "ap-southeast-3c"]

  enable_igw         = true
  enable_nat_gateway = true
  nat_gateway_name   = "NATGW"

  tags = {
    "Resource" = "VPC"
  }
}

# VPC Route Tables - Public and App (Internet Gateway and NAT routes)
module "vpc_route_tables" {
  source = "../../Terraform-Module/aws-vpc/aws-vpc-route-table"

  vpc_id   = module.vpc.vpc_id
  vpc_name = "maven-vpc"

  public_subnets      = module.vpc.public_subnet_ids
  enable_public_route = true
  internet_gateway_id = module.vpc.internet_gateway_id

  private_app_subnets = module.vpc.private_app_subnet_ids

  public_route_table_name      = "Public-RT"
  private_app_route_table_name = "Private-App-RT"

  enable_nat_route = true
  nat_gateway_ids  = module.vpc.nat_gateway_ids

  tags = {
    "Resource" = "VPC"
  }
}

# VPC Route Tables - LB and Data (no internet route)
module "vpc_route_tables_isolated" {
  source = "../../Terraform-Module/aws-vpc/aws-vpc-route-table"

  vpc_id   = module.vpc.vpc_id
  vpc_name = "maven-vpc"

  other_private_subnets_first = module.vpc.other_private_subnet_first_ids
  private_db_subnets          = module.vpc.private_db_subnet_ids

  other_private_subnets_first_route_table_name = "Private-ALB-RT"
  private_db_route_table_name                  = "Private-Data-RT"

  tags = {
    "Resource" = "VPC"
  }
}

# S3 Endpoint Gateway
module "s3_gateway_endpoint" {
  source = "../../Terraform-Module/aws-vpc-endpoint/vpc-endpoint-s3"

  vpc_id        = module.vpc.vpc_id
  region        = var.region
  endpoint_type = "Gateway"
  endpoint_name = "maven-s3-gateway-endpoint"

  route_table_ids = [
    module.vpc_route_tables_isolated.other_private_subnets_first_route_table_id,
    module.vpc_route_tables.private_app_route_table_id,
    module.vpc_route_tables_isolated.private_db_route_table_id
  ]

  tags = {
    "Resource" = "VPC"
  }
}

# Interface Endpoint - DataSync (toggle: create_datasync_agent_instance)
module "vpce_datasync" {
  source = "../../Terraform-Module/aws-vpc-endpoint/interface-endpoints"
  count  = var.create_datasync_agent_instance ? 1 : 0

  name_prefix                = "maven-datasync"
  vpc_id                     = module.vpc.vpc_id
  security_group_name        = "maven-vpce-datasync-sg"
  security_group_description = "Security Group for the DataSync interface endpoint"

  security_group_ingress_rules = [
    {
      description     = "DataSync control plane from the agent"
      from_port       = 1024
      to_port         = 1064
      protocol        = "tcp"
      security_groups = [module.sg_datasync_agent.security_group_id]
    },
    {
      description     = "DataSync data plane from the agent"
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      security_groups = [module.sg_datasync_agent.security_group_id]
    },
    {
      description     = "DataSync support channel from the agent"
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      security_groups = [module.sg_datasync_agent.security_group_id]
    }
  ]

  interface_endpoints = {
    "datasync" = {
      name                = "maven-datasync-endpoint"
      service_name        = "com.amazonaws.${var.region}.datasync"
      subnet_ids          = [module.vpc.private_app_subnet_ids[0]]
      private_dns_enabled = true
    }
  }

  tags = {
    "Resource" = "VPC"
  }
}

# DataSync Endpoint Network Interface (private IP used to activate the agent)
data "aws_network_interface" "vpce_datasync" {
  count = var.create_datasync_agent_instance ? 1 : 0
  id    = tolist(module.vpce_datasync[0].endpoint_network_interface_ids["datasync"])[0]
}

# VPC Flow Logs
module "vpc_flow_logs" {
  source = "../../Terraform-Module/aws-vpc-flow-logs"

  vpc_id         = module.vpc.vpc_id
  log_group_name = "/aws/vpc/maven-flow-logs"
  flow_log_name  = "maven-vpc-flow-log"
  traffic_type   = "ALL"
  retention_days = 30 # Flow log retention

  tags = {
    "Resource" = "VPC"
  }
}

# Site-to-Site VPN (toggle: local.customer_gateway_ip)
module "vpn_onprem" {
  source = "../../Terraform-Module/aws-vpn-site-to-site"
  count  = local.vpn_enabled ? 1 : 0

  name = "maven-vpn-onprem"

  create_customer_gateway     = true
  customer_gateway_ip_address = local.customer_gateway_ip
  customer_gateway_bgp_asn    = 65000 # TBD (Kalbe, DDD T3) - on-premises ASN when BGP is used

  create_vpn_gateway = true
  vpn_gateway_vpc_id = module.vpc.vpc_id

  static_routes_only = true # TBD (Kalbe, DDD T3) - false for BGP
  static_routes      = local.onprem_cidrs

  tunnel1_ike_versions = ["ikev2"]
  tunnel2_ike_versions = ["ikev2"]

  propagation_route_tables = {
    "alb"  = module.vpc_route_tables_isolated.other_private_subnets_first_route_table_id
    "app"  = module.vpc_route_tables.private_app_route_table_id
    "data" = module.vpc_route_tables_isolated.private_db_route_table_id
  }

  tags = {
    "Resource" = "VPN"
  }
}

# SECURITY GROUPS
# API Gateway VPC Link
module "sg_vpc_link" {
  source = "../../Terraform-Module/aws-ec2-security-group"

  name        = "maven-vpclink-sg"
  description = "Security Group for the API Gateway VPC link to the internal ALB"
  vpc_id      = module.vpc.vpc_id

  inbound_rules = []

  outbound_rules = [
    for k, s in local.services : {
      port        = s.listener_port
      protocol    = "tcp"
      cidr_blocks = [module.vpc.vpc_cidr_block]
      description = "To internal ALB listener ${k}"
    }
  ]

  tags = {
    "Resource" = "SecurityGroup"
  }
}

# Internal ALB
module "sg_alb" {
  source = "../../Terraform-Module/aws-ec2-security-group"

  name        = "maven-alb-sg"
  description = "Security Group for the internal Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  inbound_rules = concat(
    [
      for k, s in local.services : {
        port                     = s.listener_port
        protocol                 = "tcp"
        source_security_group_id = module.sg_vpc_link.security_group_id
        description              = "Production listener ${k} from API Gateway VPC link"
      }
    ],
    [
      for k, s in local.services : {
        port        = s.test_listener_port
        protocol    = "tcp"
        cidr_blocks = [module.vpc.vpc_cidr_block]
        description = "CodeDeploy test listener ${k} from the VPC"
      } if s.test_listener_port != null
    ],
    [
      for k, s in local.services : {
        port        = s.listener_port
        protocol    = "tcp"
        cidr_blocks = local.onprem_cidrs
        description = "Listener ${k} from on-premises over VPN (internal testing)"
      } if local.onprem_access_enabled
    ],
    [
      for k, s in local.services : {
        port                     = s.listener_port
        protocol                 = "tcp"
        source_security_group_id = module.sg_loadtest.security_group_id
        description              = "Listener ${k} from k6 load test"
      }
    ]
  )

  outbound_rules = [
    {
      port        = 0
      protocol    = "-1"
      cidr_blocks = [module.vpc.vpc_cidr_block]
      description = "To ECS tasks in the VPC"
    }
  ]

  tags = {
    "Resource" = "SecurityGroup"
  }
}

# ECS Tasks
module "sg_ecs" {
  source = "../../Terraform-Module/aws-ec2-security-group"

  name        = "maven-ecs-sg"
  description = "Security Group for ECS Fargate tasks"
  vpc_id      = module.vpc.vpc_id

  inbound_rules = concat(
    [
      for k, s in local.services : {
        port                     = s.container_port
        protocol                 = "tcp"
        source_security_group_id = module.sg_alb.security_group_id
        description              = "Application ${k} from ALB"
      }
    ],
    [
      for k, s in local.services : {
        port                     = s.container_port
        protocol                 = "tcp"
        source_security_group_id = module.sg_monitoring.security_group_id
        description              = "Prometheus scrape ${k}"
      }
    ]
  )

  outbound_rules = [
    {
      port        = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]

  tags = {
    "Resource" = "SecurityGroup"
  }
}

# Aurora
module "sg_aurora" {
  source = "../../Terraform-Module/aws-ec2-security-group"

  name        = "maven-aurora-sg"
  description = "Security Group for Aurora PostgreSQL"
  vpc_id      = module.vpc.vpc_id

  inbound_rules = concat(
    [
      {
        port                     = 5432
        protocol                 = "tcp"
        source_security_group_id = module.sg_ecs.security_group_id
        description              = "PostgreSQL from ECS tasks"
      }
    ],
    [
      for r in [
        {
          port        = 5432
          protocol    = "tcp"
          cidr_blocks = local.migration_host_cidrs
          description = "pg_restore from Kalbe migration host (remove after migration)"
        }
      ] : r if local.migration_access
    ]
  )

  outbound_rules = []

  tags = {
    "Resource" = "SecurityGroup"
  }
}

# ElastiCache Valkey
module "sg_valkey" {
  source = "../../Terraform-Module/aws-ec2-security-group"

  name        = "maven-valkey-sg"
  description = "Security Group for ElastiCache Valkey"
  vpc_id      = module.vpc.vpc_id

  inbound_rules = [
    {
      port                     = 6379
      protocol                 = "tcp"
      source_security_group_id = module.sg_ecs.security_group_id
      description              = "Valkey from ECS tasks"
    }
  ]

  outbound_rules = []

  tags = {
    "Resource" = "SecurityGroup"
  }
}

# Monitoring (Prometheus and Grafana)
module "sg_monitoring" {
  source = "../../Terraform-Module/aws-ec2-security-group"

  name        = "maven-monitoring-sg"
  description = "Security Group for the Prometheus and Grafana instance"
  vpc_id      = module.vpc.vpc_id

  inbound_rules = [
    for r in [
      {
        port        = 3000
        protocol    = "tcp"
        cidr_blocks = local.onprem_cidrs
        description = "Grafana web UI from on-premises over VPN"
      },
      {
        port        = 9090
        protocol    = "tcp"
        cidr_blocks = local.onprem_cidrs
        description = "Prometheus web UI from on-premises over VPN"
      },
      {
        port        = -1
        protocol    = "icmp"
        cidr_blocks = local.onprem_cidrs
        description = "Ping from on-premises for VPN connectivity test"
      }
    ] : r if local.onprem_access_enabled
  ]

  outbound_rules = [
    {
      port        = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]

  tags = {
    "Resource" = "SecurityGroup"
  }
}

# Load Test (k6)
module "sg_loadtest" {
  source = "../../Terraform-Module/aws-ec2-security-group"

  name        = "maven-loadtest-sg"
  description = "Security Group for the k6 load test instance"
  vpc_id      = module.vpc.vpc_id

  inbound_rules = []

  outbound_rules = [
    {
      port        = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]

  tags = {
    "Resource" = "SecurityGroup"
  }
}

# DataSync Agent
module "sg_datasync_agent" {
  source = "../../Terraform-Module/aws-ec2-security-group"

  name        = "maven-datasync-agent-sg"
  description = "Security Group for the DataSync agent instance"
  vpc_id      = module.vpc.vpc_id

  inbound_rules = [
    for r in [
      {
        port        = 80
        protocol    = "tcp"
        cidr_blocks = local.migration_host_cidrs
        description = "Agent activation from Kalbe migration host (remove after activation)"
      }
    ] : r if local.migration_access
  ]

  outbound_rules = [
    {
      port        = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "NAS over VPN and DataSync service endpoints"
    }
  ]

  tags = {
    "Resource" = "SecurityGroup"
  }
}
