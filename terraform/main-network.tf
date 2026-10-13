# VPC
module "vpc" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-vpc?ref=main"

  vpc_name = "shpdev-maven"
  vpc_cidr = "10.177.207.0/24"
  azs      = ["ap-southeast-3a", "ap-southeast-3b", "ap-southeast-3c"]

  public_subnets      = ["10.177.207.192/27", "10.177.207.224/28", "10.177.207.240/28"]
  public_subnet_names = ["shpdev-maven-public-3a", "shpdev-maven-public-3b", "shpdev-maven-public-3c"]
  public_subnet_azs   = ["ap-southeast-3a", "ap-southeast-3b", "ap-southeast-3c"]

  private_app_subnets      = ["10.177.207.0/26", "10.177.207.64/26", "10.177.207.128/26"]
  private_app_subnet_names = ["shpdev-maven-private-3a", "shpdev-maven-private-3b", "shpdev-maven-private-3c"]
  private_app_subnet_azs   = ["ap-southeast-3a", "ap-southeast-3b", "ap-southeast-3c"]

  enable_igw         = true
  enable_nat_gateway = true
  nat_gateway_name   = "NATGW"

  tags = {
    "Resource" = "VPC"
  }
}

# VPC Route Tables
module "vpc_route_tables" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-vpc/aws-vpc-route-table?ref=main"

  vpc_id   = module.vpc.vpc_id
  vpc_name = "shpdev-maven"

  public_subnets      = module.vpc.public_subnet_ids
  enable_public_route = true
  internet_gateway_id = module.vpc.internet_gateway_id

  private_app_subnets = module.vpc.private_app_subnet_ids

  public_route_table_name      = "Public-RT"
  private_app_route_table_name = "Private-RT"

  enable_nat_route = true
  nat_gateway_ids  = module.vpc.nat_gateway_ids

  tags = {
    "Resource" = "VPC"
  }
}

# S3 Endpoint Gateway
module "s3_gateway_endpoint" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-vpc-endpoint/vpc-endpoint-s3?ref=main"

  vpc_id        = module.vpc.vpc_id
  region        = var.region
  endpoint_type = "Gateway"
  endpoint_name = "shpdev-maven-s3-gateway-endpoint"

  route_table_ids = [
    module.vpc_route_tables.private_app_route_table_id
  ]

  tags = {
    "Resource" = "VPC"
  }
}

# Interface Endpoint - DataSync (toggle: create_datasync_agent_instance)
module "vpce_datasync" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-vpc-endpoint/interface-endpoints?ref=main"
  count  = var.create_datasync_agent_instance ? 1 : 0

  name_prefix                = "shpdev-maven-datasync"
  vpc_id                     = module.vpc.vpc_id
  security_group_name        = "shpdev-maven-vpce-datasync-sg"
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
      name                = "shpdev-maven-datasync-endpoint"
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
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-vpc-flow-logs?ref=main"

  vpc_id         = module.vpc.vpc_id
  log_group_name = "/aws/vpc/shpdev-maven-flow-logs"
  flow_log_name  = "shpdev-maven-vpc-flow-log"
  traffic_type   = "ALL"
  retention_days = 30 # Flow log retention

  tags = {
    "Resource" = "VPC"
  }
}

# Site-to-Site VPN (toggle: count)
module "vpn_onprem" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-vpn-site-to-site?ref=main"
  count  = 1 # Set to 0 to skip the Site-to-Site VPN

  name = "shpdev-maven-vpn-onprem"

  create_customer_gateway      = true
  customer_gateway_device_name = "KN-Network"
  customer_gateway_ip_address  = "103.78.44.2"
  customer_gateway_bgp_asn     = 65000 # TBD (Kalbe, DDD T3) - on-premises ASN when BGP is used

  create_vpn_gateway = true
  vpn_gateway_vpc_id = module.vpc.vpc_id

  static_routes_only = true # TBD (Kalbe, DDD T3) - false for BGP
  static_routes      = []   # TBD (Kalbe, DDD T2) - on-premises CIDRs behind the VPN

  tunnel1_ike_versions = ["ikev2"]
  tunnel2_ike_versions = ["ikev2"]

  propagation_route_tables = {
    "private" = module.vpc_route_tables.private_app_route_table_id
  }

  tags = {
    "Resource" = "VPN"
  }
}

# SECURITY GROUPS
# API Gateway VPC Link
module "sg_vpc_link" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-ec2-security-group?ref=main"

  name        = "shpdev-maven-vpclink-sg"
  description = "Security Group for the API Gateway VPC link to the internal ALB"
  vpc_id      = module.vpc.vpc_id

  inbound_rules = []

  outbound_rules = [
    {
      port        = 8443
      protocol    = "tcp"
      cidr_blocks = [module.vpc.vpc_cidr_block]
      description = "To internal ALB HTTPS listener dofs"
    },
    {
      port        = 8444
      protocol    = "tcp"
      cidr_blocks = [module.vpc.vpc_cidr_block]
      description = "To internal ALB HTTPS listener shortenurl"
    }
  ]

  tags = {
    "Resource" = "SecurityGroup"
  }
}

# Internal ALB
module "sg_alb" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-ec2-security-group?ref=main"

  name        = "shpdev-maven-alb-sg"
  description = "Security Group for the internal Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  inbound_rules = concat(
    [
      {
        port                     = 8443
        protocol                 = "tcp"
        source_security_group_id = module.sg_vpc_link.security_group_id
        description              = "Listener dofs from API Gateway VPC link"
      },
      {
        port                     = 8444
        protocol                 = "tcp"
        source_security_group_id = module.sg_vpc_link.security_group_id
        description              = "Listener shortenurl from API Gateway VPC link"
      },
      {
        port        = 9443
        protocol    = "tcp"
        cidr_blocks = [module.vpc.vpc_cidr_block]
        description = "CodeDeploy test listener dofs from the VPC"
      },
      {
        port        = 9444
        protocol    = "tcp"
        cidr_blocks = [module.vpc.vpc_cidr_block]
        description = "CodeDeploy test listener shortenurl from the VPC"
      },
      {
        port                     = 8443
        protocol                 = "tcp"
        source_security_group_id = module.sg_loadtest.security_group_id
        description              = "Listener dofs from k6 load test"
      },
      {
        port                     = 8444
        protocol                 = "tcp"
        source_security_group_id = module.sg_loadtest.security_group_id
        description              = "Listener shortenurl from k6 load test"
      }
    ],
    [for r in [
      {
        port        = 8443
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"] # Kalbe network (DDD T6)
        description = "Listener dofs from on-premises over VPN"
      },
      {
        port        = 8444
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"] # Kalbe network (DDD T6)
        description = "Listener shortenurl from on-premises over VPN"
      },
      {
        port        = 80
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"] # Kalbe network (DDD T6)
        description = "Web HTTP port from Kalbe network"
      }
    ] : r if length(r.cidr_blocks) > 0]
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
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-ec2-security-group?ref=main"

  name        = "shpdev-maven-ecs-sg"
  description = "Security Group for ECS Fargate tasks"
  vpc_id      = module.vpc.vpc_id

  inbound_rules = [
    {
      port                     = 80
      protocol                 = "tcp"
      source_security_group_id = module.sg_alb.security_group_id
      description              = "Application traffic and health check from ALB (container port, DDD T17)"
    },
    {
      port                     = 8080
      protocol                 = "tcp"
      source_security_group_id = module.sg_alb.security_group_id
      description              = "Application traffic and health check from ALB (DDD T6)"
    },
    {
      port                     = 80
      protocol                 = "tcp"
      source_security_group_id = module.sg_monitoring.security_group_id
      description              = "Prometheus scrape of /metrics (container port, DDD T17)"
    },
    {
      port                     = 8080
      protocol                 = "tcp"
      source_security_group_id = module.sg_monitoring.security_group_id
      description              = "Prometheus scrape of /metrics (DDD T6)"
    }
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

# Aurora
module "sg_aurora" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-ec2-security-group?ref=main"

  name        = "shpdev-maven-aurora-sg"
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
    [for r in [
      {
        port        = 5432
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"] # Kalbe migration host (DDD T6); narrow to the host /32 when known
        description = "pg_restore from Kalbe migration host (remove after migration)"
      }
    ] : r if length(r.cidr_blocks) > 0]
  )

  outbound_rules = []

  tags = {
    "Resource" = "SecurityGroup"
  }
}

# ElastiCache Valkey
module "sg_valkey" {
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-ec2-security-group?ref=main"

  name        = "shpdev-maven-valkey-sg"
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
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-ec2-security-group?ref=main"

  name        = "shpdev-maven-monitoring-sg"
  description = "Security Group for the Prometheus and Grafana instance"
  vpc_id      = module.vpc.vpc_id

  inbound_rules = [
    for r in [
      {
        port        = 3000
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"] # Kalbe network (DDD T6)
        description = "Grafana web UI from on-premises over VPN"
      },
      {
        port        = 9090
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"] # Kalbe network (DDD T6)
        description = "Prometheus web UI from on-premises over VPN"
      },
      {
        port        = -1
        protocol    = "icmp"
        cidr_blocks = ["10.0.0.0/8"] # Kalbe network (DDD T6)
        description = "Ping from on-premises for VPN connectivity test"
      }
    ] : r if length(r.cidr_blocks) > 0
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
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-ec2-security-group?ref=main"

  name        = "shpdev-maven-loadtest-sg"
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
  source = "git::https://github.com/IrfanSob/awsshp-maven.git//modules/aws-ec2-security-group?ref=main"

  name        = "shpdev-maven-datasync-agent-sg"
  description = "Security Group for the DataSync agent instance"
  vpc_id      = module.vpc.vpc_id

  inbound_rules = [
    for r in [
      {
        port        = 80
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"] # Kalbe migration host (DDD T6); narrow to the host /32 when known
        description = "Agent activation from Kalbe migration host (remove after activation)"
      }
    ] : r if length(r.cidr_blocks) > 0
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
