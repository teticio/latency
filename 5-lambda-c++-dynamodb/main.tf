data "aws_region" "current" {}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "bucket" {
  bucket        = "latency-lambda-dynamodb-${random_string.bucket_suffix.result}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.bucket.id

  policy = <<-EOL
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": "*",
          "Action": "s3:GetObject",
          "Resource": "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}/index.html"
        }
      ]
    }
  EOL

  depends_on = [aws_s3_bucket_public_access_block.public_access_block]
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.bucket.bucket
  key          = "index.html"
  source       = "${path.root}/common/index.html"
  content_type = "text/html"
}

resource "aws_dynamodb_table" "dynamodb" {
  name         = "latency"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "N"
  }
}

module "lambda_function" {
  source                 = "terraform-aws-modules/lambda/aws"
  function_name          = "hits"
  handler                = "foobar"
  runtime                = "provided"
  attach_policy_json     = true
  publish                = true
  create_package         = false
  local_existing_package = "${path.module}/build/lambda.zip"

  policy_json = <<-EOL
    {
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Action": [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ],
        "Resource": "${aws_dynamodb_table.dynamodb.arn}"
      }]
    }
  EOL

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      source_arn = "${module.api_gateway.api_execution_arn}/*/*/*"
    }
  }
}

module "api_gateway" {
  source             = "terraform-aws-modules/apigateway-v2/aws"
  name               = "latency"
  description        = "app"
  protocol_type      = "HTTP"
  create_domain_name = false

  routes = {
    "GET /" = {
      integration = {
        type   = "HTTP_PROXY"
        uri    = "https://${aws_s3_bucket.bucket.id}.s3.${data.aws_region.current.region}.amazonaws.com/${aws_s3_object.index.id}"
        method = "GET"
      }
    }

    "GET /hits" = {
      integration = {
        type   = "AWS_PROXY"
        uri    = "${module.lambda_function.lambda_function_arn}"
        method = "GET"
      }
    }
  }
}
