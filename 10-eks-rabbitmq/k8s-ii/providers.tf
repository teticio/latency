terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }

    docker = {
      source = "kreuzwerker/docker"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "aws" {
  default_tags {
    tags = {
      Name = "latency-fastapi-ec2"
    }
  }
}

data "aws_region" "current" {}

data "aws_caller_identity" "this" {}

data "aws_ecr_authorization_token" "token" {}

provider "docker" {
  registry_auth {
    address  = format("%v.dkr.ecr.%v.amazonaws.com", data.aws_caller_identity.this.account_id, data.aws_region.current.name)
    username = data.aws_ecr_authorization_token.token.user_name
    password = data.aws_ecr_authorization_token.token.password
  }
}

provider "kubernetes" {
  host                   = var.cluster_endpoint
  token                  = var.cluster_token
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}
