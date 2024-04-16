module "lambda_function" {
  source        = "terraform-aws-modules/lambda/aws"
  function_name = "test-latency"
  handler       = "latency.lambda_handler"
  runtime       = "python3.8"
  timeout       = 300

  source_path = [
    "./latency.py",
    {
      pip_requirements = "requirements.txt",
    }
  ]
}
