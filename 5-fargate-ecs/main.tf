data "aws_region" "current" {}

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

resource "aws_ecr_repository" "latency" {
  name = "latency"

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
  count           = length(aws_subnet.private.*.id)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = element(aws_subnet.private.*.id, count.index)
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
    assign_public_ip = false
    subnets          = aws_subnet.private.*.id

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
  "image": "${aws_ecr_repository.latency.repository_url}:latest",
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
  vpc_id      = aws_vpc.app_vpc.id

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
  subnets            = aws_subnet.public.*.id

  security_groups = [
    aws_security_group.http.id,
    aws_security_group.https.id,
    aws_security_group.egress_all.id,
  ]

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = var.tag
  }
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_alb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = {
    Name = var.tag
  }
}

data "aws_route53_zone" "this" {
  name         = var.hosted_zone
  private_zone = false
}

resource "aws_acm_certificate" "this" {
  domain_name       = var.domain
  validation_method = "DNS"

  tags = {
    Name = var.tag
  }
}

resource "aws_route53_record" "this" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this.zone_id
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.this : record.fqdn]
}

resource "aws_alb_listener" "https" {
  load_balancer_arn = aws_alb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate_validation.this.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = {
    Name = var.tag
  }
}

resource "aws_route53_record" "www" {
  zone_id         = data.aws_route53_zone.this.zone_id
  name            = var.domain
  type            = "A"
  allow_overwrite = true

  alias {
    evaluate_target_health = true
    name                   = aws_alb.this.dns_name
    zone_id                = aws_alb.this.zone_id
  }
}
