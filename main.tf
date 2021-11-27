terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = var.region
}

module "app" {
  source = "./1-fastapi-ec2"
  key_name = var.key_name
  key_path = var.key_path
}
