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

module "lambda_function" {
  source        = "terraform-aws-modules/lambda/aws"
  function_name = "test-latency"
  handler       = "latency.lambda_handler"
  runtime       = "python3.8"
  timeout       = 30

  source_path = [
    "./latency.py",
    {
      pip_requirements = "requirements.txt",
    }
  ]
}
