# IAM roles for ECS tasks and execution role ===== #
resource "aws_iam_role" "ecs_execution_role" {
  name               = "${local.prefix}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_attachment" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "${local.prefix}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_ssm" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

# ECS Cluster ========================= #
resource "aws_ecs_cluster" "main" {
  name = "${local.prefix}-cluster"

  tags = {
    Name = "${local.prefix}-cluster"
  }
}

# ECS log group ======================= #
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.prefix}"
  retention_in_days = 7

  tags = {
    Name = "/ecs/${local.prefix}"
  }
}

# task definition ========================= #
resource "aws_ecs_task_definition" "watchlist_api" {
  family                   = "${local.prefix}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = "nginx:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }


  ])

  tags = {
    Name = "${local.prefix}-task"
  }
}

# ECS service ========================= #
resource "aws_ecs_service" "watchlist_api" {
  name            = "${local.prefix}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.watchlist_api.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    # subnets         = aws_subnet.public[*].id XXX
    subnets          = values(aws_subnet.public)[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }
  tags = {
    Name = "${local.prefix}-service"
  }
}

# Security group for ECS tasks ========================= #
resource "aws_security_group" "ecs" {
  name        = "${local.prefix}-ecs-sg"
  description = "Allow inbound traffic to ECS tasks"
  vpc_id      = aws_vpc.main.id
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
  tags = {
    Name = "${local.prefix}-ecs-sg"
  }
}
