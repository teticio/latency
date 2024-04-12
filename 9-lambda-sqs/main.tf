// with help from https://gist.github.com/afloesch/dc7d8865eeb91100648330a46967be25

data "aws_region" "current" {}

module "lambda_function" {
  source             = "terraform-aws-modules/lambda/aws"
  function_name      = "calc"
  handler            = "calc.lambda_handler"
  runtime            = "python3.8"
  source_path        = "${path.module}/calc.py"
  timeout            = 30
  publish            = true
  attach_policy_json = true

  policy_json = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
        ],
        Resource = aws_sqs_queue.queue.arn
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ],
        Resource = aws_dynamodb_table.dynamodb.arn
      }
    ]
  })

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "sqs"
      source_arn = aws_sqs_queue.queue.arn
    }
  }

  tags = {
    Name = var.tag
  }
}

resource "aws_dynamodb_table" "dynamodb" {
  name           = "latency"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "N"
  }

  tags = {
    Name = var.tag
  }
}

resource "aws_sqs_queue" "dead_letter_queue" {
  name = "latency-dead-letter-queue"

  tags = {
    Name = var.tag
  }
}

resource "aws_sqs_queue" "queue" {
  name                       = "latency"
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 10
  visibility_timeout_seconds = 30

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter_queue.arn
    maxReceiveCount     = 1
  })

  tags = {
    Name = var.tag
  }
}

resource "aws_lambda_event_source_mapping" "queue" {
  event_source_arn = aws_sqs_queue.queue.arn
  function_name    = module.lambda_function.lambda_function_name
}

resource "aws_iam_role" "api" {
  name = "latency"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })

  tags = {
    Name = var.tag
  }
}

resource "aws_iam_policy" "api" {
  name = "latency"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "sqs:SendMessage",
        ],
        Effect   = "Allow",
        Resource = aws_sqs_queue.queue.arn
      },
    ],
  })

  tags = {
    Name = var.tag
  }
}

resource "aws_iam_role_policy_attachment" "api" {
  role       = aws_iam_role.api.name
  policy_arn = aws_iam_policy.api.arn
}

resource "aws_api_gateway_rest_api" "api" {
  name = "latency"

  tags = {
    Name = var.tag
  }
}

resource "aws_api_gateway_method" "api" {
  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_rest_api.api.root_resource_id
  api_key_required     = false
  http_method          = "POST"
  authorization        = "NONE"
  request_validator_id = aws_api_gateway_request_validator.api.id

  request_models = {
    "application/json" = "${aws_api_gateway_model.api.name}"
  }
}

resource "aws_api_gateway_integration" "api" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_rest_api.api.root_resource_id
  http_method             = "POST"
  type                    = "AWS"
  integration_http_method = "POST"
  passthrough_behavior    = "NEVER"
  credentials             = aws_iam_role.api.arn
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:sqs:path/${aws_sqs_queue.queue.name}"

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$input.body"
  }
}

resource "aws_api_gateway_request_validator" "api" {
  rest_api_id           = aws_api_gateway_rest_api.api.id
  name                  = "payload-validator"
  validate_request_body = true
}

resource "aws_api_gateway_model" "api" {
  rest_api_id  = aws_api_gateway_rest_api.api.id
  name         = "PayloadValidator"
  description  = "validate the json body content conforms to the below spec"
  content_type = "application/json"

  schema = jsonencode({
    "$schema"  = "http://json-schema.org/draft-04/schema#",
    "type"     = "object",
    "required" = ["x"],
    "properties" = {
      "x" = {
        "type" = "number"
      }
    }
  })
}

resource "aws_api_gateway_integration_response" "ok" {
  rest_api_id       = aws_api_gateway_rest_api.api.id
  resource_id       = aws_api_gateway_rest_api.api.root_resource_id
  http_method       = aws_api_gateway_method.api.http_method
  status_code       = aws_api_gateway_method_response.ok.status_code
  selection_pattern = "^2[0-9][0-9]"

  response_templates = {
    "application/json" = "{\"message\": \"OK\"}"
  }

  depends_on = [aws_api_gateway_integration.api]
}

resource "aws_api_gateway_method_response" "ok" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.api.http_method
  status_code = 200

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "main"

  depends_on = [
    aws_api_gateway_integration.api,
  ]
}
