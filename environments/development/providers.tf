# Default AWS Provider (Jakarta - ap-southeast-3)
provider "aws" {
  region              = var.region
  allowed_account_ids = ["908027374739"]
  default_tags {
    tags = var.aws_default_tags
  }
}

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket       = "terraform-kalbe-maven-908027374739"
    key          = "terraform-state/kalbe-maven-908027374739.tfstate"
    region       = "ap-southeast-3"
    encrypt      = true
    use_lockfile = true
  }
}
