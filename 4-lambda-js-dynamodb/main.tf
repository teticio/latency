data "aws_region" "current" {}

resource "aws_s3_bucket" "bucket" {
  bucket        = "latency-lambda-dynamodb"
  force_destroy = true
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.bucket.bucket
  acl          = "public-read"
  key          = "index.html"
  source       = "${path.root}/common/index.html"
  content_type = "text/html"
}

resource "aws_dynamodb_table" "dynamodb" {
  name           = "latency"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "N"
  }
}

module "lambda_function" {
  source             = "terraform-aws-modules/lambda/aws"
  function_name      = "hits"
  handler            = "hits.lambda_handler"
  runtime            = "nodejs12.x"
  source_path        = "${path.module}/hits.js"
  attach_policy_json = true
  publish            = true

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
      source_arn = "${module.api_gateway.apigatewayv2_api_execution_arn}/*/*/*"
    }
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
      integration_uri    = "https://${aws_s3_bucket.bucket.id}.s3.${data.aws_region.current.name}.amazonaws.com/${aws_s3_object.index.id}"
      integration_type   = "HTTP_PROXY"
      integration_method = "GET"
    }

    "GET /hits" = {
      lambda_arn = module.lambda_function.lambda_function_arn
    }
  }
}
