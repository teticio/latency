data "aws_region" "current" {}

data "aws_vpc" "this" {
  default = true
}

data "aws_subnet_ids" "this" {
  vpc_id = data.aws_vpc.this.id
}

resource "aws_security_group" "http" {
  name   = "http"
  vpc_id = data.aws_vpc.this.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.tag
  }
}

resource "aws_security_group" "https" {
  name   = "https"
  vpc_id = data.aws_vpc.this.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.tag
  }
}

resource "aws_security_group" "egress_all" {
  name   = "egress_all"
  vpc_id = data.aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.tag
  }
}

resource "aws_security_group" "ingress_api" {
  name   = "ingress_api"
  vpc_id = data.aws_vpc.this.id

  ingress {
    description = "API"
    from_port   = 8000
    to_port     = 8000
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.tag
  }
}

resource "aws_security_group" "efs" {
  name   = "efs"
  vpc_id = data.aws_vpc.this.id

  ingress {
    description = "NFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.tag
  }
}

resource "aws_ecs_cluster" "this" {
  name               = "latency"
  capacity_providers = ["FARGATE_SPOT", "FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
  }
  
  tags = {
    Name = var.tag
  }
}

resource "aws_efs_access_point" "this" {
  file_system_id = aws_efs_file_system.this.id

  tags = {
    Name = var.tag
  }
}

resource "aws_efs_mount_target" "this" {
  count           = length(data.aws_subnet_ids.this.ids)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = sort(data.aws_subnet_ids.this.ids)[count.index]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_cloudwatch_log_group" "this" {
  name = "/ecs/latency"

  tags = {
    Name = var.tag
  }
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
    subnets          = data.aws_subnet_ids.this.ids

    security_groups = [
      aws_security_group.egress_all.id,
      aws_security_group.ingress_api.id
    ]
  }

  tags = {
    Name = var.tag
  }
}

resource "aws_efs_file_system" "this" {
  creation_token = "latency"

  tags = {
    Name = var.tag
  }
}

resource "aws_ecs_task_definition" "this" {
  family = "latency"

  container_definitions = <<EOF
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
  EOF

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

  tags = {
    Name = var.tag
  }
}

resource "aws_iam_role" "task_execution_role" {
  name               = "latency-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = {
    Name = var.tag
  }
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
  vpc_id      = data.aws_vpc.this.id

  health_check {
    enabled             = true
    path                = "/healthz"
  }

  depends_on = [aws_alb.this]

  tags = {
    Name = var.tag
  }
}

resource "aws_alb" "this" {
  name               = "latency"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.this.ids

  security_groups = [
    aws_security_group.http.id,
    aws_security_group.https.id,
    aws_security_group.egress_all.id,
  ]

  tags = {
    Name = var.tag
  }
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_alb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = {
    Name = var.tag
  }
}
