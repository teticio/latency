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
  #  source   = "./1-fastapi-ec2"
  #  source = "./2-lambda-s3"
  source = "./3-lambda-dynamodb"
}
