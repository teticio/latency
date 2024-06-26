data "aws_region" "current" {}

data "aws_vpc" "default" {
  count   = var.vpc_id == "" ? 1 : 0
  default = true
}

locals {
  vpc_id = var.vpc_id == "" ? tolist(data.aws_vpc.default.*.id)[0] : var.vpc_id
}

data "aws_subnets" "this" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

resource "aws_security_group" "http" {
  name   = "http"
  vpc_id = local.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "https" {
  name   = "https"
  vpc_id = local.vpc_id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "egress_all" {
  name   = "egress_all"
  vpc_id = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress_api" {
  name   = "ingress_api"
  vpc_id = local.vpc_id

  ingress {
    description = "API"
    from_port   = 8000
    to_port     = 8000
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "efs" {
  name   = "efs"
  vpc_id = local.vpc_id

  ingress {
    description = "NFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster" "this" {
  name = "latency"
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
  }
}

resource "aws_efs_access_point" "this" {
  file_system_id = aws_efs_file_system.this.id
}

resource "aws_efs_mount_target" "this" {
  count          = length(data.aws_subnets.this.ids)
  file_system_id = aws_efs_file_system.this.id
  subnet_id      = sort(data.aws_subnets.this.ids)[count.index]

  security_groups = [
    aws_security_group.efs.id,
    aws_security_group.egress_all.id
  ]
}

resource "aws_cloudwatch_log_group" "this" {
  name = "/ecs/latency"
}

resource "aws_ecs_service" "this" {
  name            = "latency"
  task_definition = aws_ecs_task_definition.this.arn
  cluster         = aws_ecs_cluster.this.id
  launch_type     = "FARGATE"
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "latency"
    container_port   = "8000"
  }

  network_configuration {
    assign_public_ip = true
    subnets          = data.aws_subnets.this.ids

    security_groups = [
      aws_security_group.egress_all.id,
      aws_security_group.ingress_api.id
    ]
  }
}

resource "aws_efs_file_system" "this" {
  creation_token = "latency"
}

resource "aws_ecs_task_definition" "this" {
  family = "latency"

  container_definitions = <<-EOL
    [{
      "name": "latency",
      "image": "teticio/latency:latest",
      "environment": [
        {
          "name": "COUNT_FILE",
          "value": "/mnt/efs/count"
        }
      ],
      "portMappings": [{
        "containerPort": 8000
      }],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-region": "${data.aws_region.current.name}",
          "awslogs-group": "/ecs/latency",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "mountPoints": [{
        "sourceVolume": "${aws_efs_file_system.this.creation_token}",
        "containerPath": "/mnt/efs",
        "readOnly": false
      }]
    }]
  EOL

  volume {
    name = "latency"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.this.id
      root_directory = "/"
    }
  }

  execution_role_arn       = aws_iam_role.task_execution_role.arn
  cpu                      = 256
  memory                   = 512
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

}

resource "aws_iam_role" "task_execution_role" {
  name               = "latency-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "ecs_task_execution_role" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = data.aws_iam_policy.ecs_task_execution_role.arn
}

resource "aws_lb_target_group" "this" {
  name        = "latency"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = local.vpc_id

  health_check {
    enabled = true
    path    = "/healthz"
  }

  depends_on = [aws_alb.this]
}

resource "aws_alb" "this" {
  name               = "latency"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnets.this.ids

  security_groups = [
    aws_security_group.http.id,
    aws_security_group.https.id,
    aws_security_group.egress_all.id,
  ]
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_alb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
