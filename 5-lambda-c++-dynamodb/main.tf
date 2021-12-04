data "aws_region" "current" {}

resource "aws_s3_bucket" "bucket" {
  bucket        = "latency-lambda-dynamodb"
  acl           = "private"
  force_destroy = true

  tags = {
    Name = var.tag
  }
}

resource "aws_s3_bucket_object" "index" {
  bucket       = aws_s3_bucket.bucket.bucket
  acl          = "public-read"
  key          = "index.html"
  source       = "${path.root}/common/index.html"
  content_type = "text/html"

  tags = {
    Name = var.tag
  }
}

resource "aws_dynamodb_table" "dynamodb" {
  name         = "latency"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "N"
  }

  tags = {
    Name = var.tag
  }
}

module "lambda_function" {
  source                 = "terraform-aws-modules/lambda/aws"
  function_name          = "hits"
  handler                = "hello"
  runtime                = "provided"
  attach_policy_json     = true
  publish                = true
  create_package         = false
  local_existing_package = "latency.zip"

  policy_json = <<EOF
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
  EOF

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      source_arn = "${module.api_gateway.apigatewayv2_api_execution_arn}/*/*/*"
    }
  }

  tags = {
    Name = var.tag
  }
}

module "api_gateway" {
  source                 = "terraform-aws-modules/apigateway-v2/aws"
  name                   = "latency"
  description            = "app"
  protocol_type          = "HTTP"
  create_api_domain_name = false

  integrations = {
    "GET /" = {
      integration_uri    = "https://${aws_s3_bucket.bucket.id}.s3.${data.aws_region.current.name}.amazonaws.com/${aws_s3_bucket_object.index.id}"
      integration_type   = "HTTP_PROXY"
      integration_method = "GET"
    }

    "GET /hits" = {
      lambda_arn = module.lambda_function.lambda_function_arn
    }
  }
}
