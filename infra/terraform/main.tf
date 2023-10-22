terraform {
  backend "s3" {
    encrypt = true
    bucket  = var.bucket_name
    key     = var.bucket_key
    region  = var.aws_region
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
  # access_key = var.access_key
  # secret_key = var.secret_key
}



resource "aws_ecr_repository" "aws_ecr_repository" {
  name         = "aws_ecr_repository-${var.resource_tags["project"]}-${var.resource_tags["environment"]}"
  force_delete = true
}

resource "aws_ecs_cluster" "aws_ecs_service" {
  name = "aws_ecs_service-${var.resource_tags["project"]}-${var.resource_tags["environment"]}"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "aws_ecs_task_definition" {
  family                = "aws_ecs_task_definition"
  container_definitions = <<DEFINITION
[
  {
    "name": "aws-${var.resource_tags["project"]}-${var.resource_tags["environment"]}-container",
    "image": "${aws_ecr_repository.aws_ecr_repository.repository_url}",
    "essential": true,
    "portMappings": [
      {
        "containerPort": ${var.container_port},
        "hostPort": ${var.host_port}
      }
    ],
    "memory": ${var.memory},
    "cpu": ${var.cpu}
  }
]
DEFINITION

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = var.memory
  cpu                      = var.cpu
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
}

resource "aws_default_vpc" "default_vpc" {
}

resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "${var.aws_region}a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "${var.aws_region}b"
}

resource "aws_default_subnet" "default_subnet_c" {
  availability_zone = "${var.aws_region}c"
}

resource "aws_alb" "aws_alb" {
  name               = "aws-${var.resource_tags["project"]}-${var.resource_tags["environment"]}-lb"
  load_balancer_type = "application"
  subnets = [
    "${aws_default_subnet.default_subnet_a.id}",
    "${aws_default_subnet.default_subnet_b.id}",
    "${aws_default_subnet.default_subnet_c.id}"
  ]
  security_groups = ["${aws_security_group.aws-lb_security_group.id}"]
}

resource "aws_security_group" "aws-lb_security_group" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "aws_lb_target_group" {
  name        = "target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.default_vpc.id
  health_check {
    matcher = "200,301,302"
    path    = "/"
  }
}

resource "aws_lb_listener" "aws_lb_listener" {
  load_balancer_arn = aws_alb.aws_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.aws_lb_target_group.arn
  }
}

resource "aws_ecs_service" "aws_ecs_service" {
  name            = "aws-${var.resource_tags["project"]}-${var.resource_tags["environment"]}-service"
  cluster         = aws_ecs_cluster.aws_ecs_service.id
  task_definition = aws_ecs_task_definition.aws_ecs_task_definition.arn
  launch_type     = "FARGATE"
  desired_count   = 3

  load_balancer {
    target_group_arn = aws_lb_target_group.aws_lb_target_group.arn
    container_name   = "aws-${var.resource_tags["project"]}-${var.resource_tags["environment"]}-container"
    container_port   = var.container_port
  }

  network_configuration {
    subnets          = ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}", "${aws_default_subnet.default_subnet_c.id}"]
    assign_public_ip = true
    security_groups  = ["${aws_security_group.aws_security_group.id}"]
  }
}

resource "aws_security_group" "aws_security_group" {
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = ["${aws_security_group.aws-lb_security_group.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# resource "aws_s3_bucket" "terraform_state" {
#   bucket = var.bucket_name
#   versioning {
#     enabled = true
#   }
# }
