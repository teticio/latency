## Latency

The purpose of this repo is to compare the performance of various architectures for a simple web applciation with a backend that keeps track of the number of times it has been called.

Each architecture can be built by running
```
terraform apply
```
in the root directory. The application URL will be output once the process is complete. To switch between the various architectures, change the line
```
  source   = "./1-fastapi-ec2"
```
in `main.tf` to point to the corresponding directory.

* **FastAPI + EC2** (`1-fastapi-ec2`). Serverful architecture. Spins up an EC2 instance and installs a Python FastAPI server which serves the web page, provides an end-point to increment & return a in-memory counter. The server is exposed on port 8000.

* **Lambda + S3** (`2-lambda-s3`). Serverless architecture. API Gateway serves the web page from S3 bucket and provides route to a Lambda function which stores the counter as an object in a S3 bucket.

* **Lambda + DynamoDB** (`3-lambda-dynamodb`). Serverless architecture. API Gateway serves the web page from S3 bucket and provides route to a (Python) Lambda function which stores the counter as an item in a DynamoDB table.

* **Lambda JS + DynamoDB** (`4-lambda-js-dynamodb`). Same as above, but with a JavaScript Lambda function.

* **Fargate ECS** (`5-fargate-ecs`). Serverless architecture. Given an existing hosted zone managed by AWS and associated domain name (set in `5-fargate-ecs\variables.tf`) creates a VPC, private and public subnet, NAT, ALB and Fargate ECS service that runs the FastAPI as a task. An image must be built by running `docker build . --tag *aws_account_id*.dkr.ecr.*region*.amazonaws.com/latency:latest` from the root directory and pushed to ECR with `docker push *aws_account_id*.dkr.ecr.*region*.amazonaws.com/latency:latest`. Note that the ECR repository `latency` must first be created with `terraform apply` and that you will have to push your image every time you recrate the infrastructure. I got a lot of help from this excellent guide https://section411.com/2019/07/hello-world/.

To test the performance over the internet run
```
python test\latency.py <URL>/hits 1000
```
providing the application URL and the number of times to increment the counter in succession. Alternatively, you can invoke the test from a Lambda function. Build the Lambda function by running `terraform apply` in the `test` directory and launch the test with
```
python test\lambda-latency.py <URL>/hits 1000
```
