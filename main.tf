module "app" {
   source = "./1-fastapi-ec2"
  #  source = "./2-lambda-s3"
  #  source = "./3-lambda-python-dynamodb"
  #  source = "./4-lambda-js-dynamodb"
  #  source = "./5-lambda-c++-dynamodb"
  #  source = "./6-lambda-rust-dynamodb"
  #  source = "./7-fargate-ecs"
  #  8-k8s/deploy.sh <your Route53 managed domain>
  #  source = "./9-lambda-sqs"
  #  terragrunt run-all apply
}
