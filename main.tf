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
  #  source = "./1-fastapi-ec2"
  #  source = "./2-lambda-s3"
  #  source = "./3-lambda-python-dynamodb"
  #  source = "./4-lambda-js-dynamodb"
  #  source = "./5-lambda-c++-dynamodb"
  source = "./6-lambda-rust-dynamodb"
  #  source = "./7-fargate-ecs"
}
