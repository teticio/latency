## Latency

The purpose of this repo is to compare the performance of various architectures for a simple web application with a backend that keeps track of the number of times it has been called.

Each architecture can be built by running
```
terraform apply
```
in the root directory. The application URL will be output once the process is complete. To switch between the various architectures, change the line
```
  source   = "./1-fastapi-ec2"
```
in `main.tf` to point to the corresponding directory.

* **FastAPI + EC2** (`1-fastapi-ec2`). "Serverful" architecture. Spins up an EC2 instance and installs a Python FastAPI server which serves the web page, provides an end-point to increment & return a in-memory counter. The server is exposed on port 8000.

* **Lambda + S3** (`2-lambda-s3`). Serverless architecture. API Gateway serves the web page from S3 bucket and provides route to a Lambda function which stores the counter as an object in a S3 bucket. Note that AWS resuses Lambda functions as much as possible, meaning that moving as much initialization code outside of the handler function itself improves the latency significantly.

* **Lambda + DynamoDB** (`3-lambda-dynamodb`). Serverless architecture. API Gateway serves the web page from S3 bucket and provides route to a (Python) Lambda function which stores the counter as an item in a DynamoDB table.

* **Lambda JS + DynamoDB** (`4-lambda-js-dynamodb`). Same as above, but with a JavaScript Lambda function.

* **Fargate ECS** (`5-fargate-ecs`). Serverless architecture. Creates a Fargate ECS service and Load Balancer on the default VPC (for simplicity) that runs the FastAPI server as a task inside a container. One advantage of using Fargate is that it can be configured to use spot instances which are up to 70% cheaper than on-demand instances. As spot instances can be terminated at any time (although, in practice, this is only about 5% of the time), the app persists its state on Elastic File Storage (EFS). You can build the Docker image yourself by running `docker build .` in the root directory of the repository.

* **Kubernetes** (`6-k8s`). The main alternatives for creating a Kubernetes cluster on AWS are kOps and AWS EKS. An advantage of using Kubernetes is that you can build a complex application from individually scalable and re-deployable microservices that is cloud vendor agnostic. With kOps it is a lot easier to create a cluster than with EKS using Terraform. It is also cheaper (the control node costs $46.52 a month, whereas the EKS cluster comes in at $73 not including the worker nodes). It allows finer grained control, but it is arguably harder to configure, if you are used to using the AWS console. To build the cluster and install the application, run `./6-8ks/apply.sh <Your Route53 managed domain>` in a bash shell - be patient, the whole process can take up to 20 minutes. (To tear it down again, run `./6-8ks/destroy.sh <Your Route53 managed domain>`). You will need to have installed [kOps](https://kops.sigs.k8s.io/getting_started/install/), [kubectl](https://kubernetes.io/docs/tasks/tools/) and bash.

To test the performance over the internet run
```
python test\latency.py <URL>/hits 1000
```
providing the application URL and the number of times to increment the counter in succession. Alternatively, you can invoke the test from a Lambda function. Build the Lambda function by running `terraform apply` in the `test` directory and launch the test with
```
python test\lambda-latency.py <URL>/hits 1000
```

## Results

The cost estimates are based on current AWS pricing for the region `eu-west-2` and don't take into account network usage. I have included EC2, Lambda, S3, DynamoDB, EFS and API Gateway costs.

| Architecture         | Average latency (ms) | Monthly cost ($) | Cost per million calls ($) |
|----------------------|:--------------------:|:----------------:|:--------------------------:|
| FastAPI + EC2        | 13                   | 10.57            | N/A                        |
| Lambda + S3          | 120                  | N/A              | 7.16                       |
| Lambda + DynamoDB    | 60                   | N/A              | 3.24                       |
| Lambda JS + DynamoDB | 105                  | N/A              | 3.39                       |
| Fargate Spot ECS     | 16                   | 3.11\*           | N/A                        |
| Kubernetes           | 13                   | 59.81            | N/A                        |

\* I haven't included the Elastic Load Balancer here as this is something you would probably want anyway. Even for a minimalist example, it is not possible to set up and access a Fargate cluster without one. It will set you back at least $19.32 a month.
