# execution role for ECS tasks
resource "aws_iam_role" "ecs_execution_role" {
  name               = "${local.prefix}-ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_exec_attach_managed" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# task role for ECS tasks
resource "aws_iam_role" "ecs_task_role" {
  name               = "${local.prefix}-ecsTaskRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

# what the task can do (permissions)
resource "aws_iam_role_policy_attachment" "ecs_task_attach_s3_readonly" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${local.prefix}-ecs-cluster"
  # capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  tags = {
    Name = "${local.prefix}-ecs-cluster"
  }
}

# ECS Log Group
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.prefix}"
  retention_in_days = 7
  tags = {
    Name = "${local.prefix}-ecs-log-group"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${local.prefix}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  # container_definitions    = templatefile("${path.module}/templates/ecs-task-def.json.tpl", {
  #     log_group_name = aws_cloudwatch_log_group.ecs.name
  #     prefix         = local.prefix
  #     image          = var.app_image
  # })
  # container_definitions = jsonencode({})

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = "nginx:alpine"
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
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "${local.prefix}-ecs-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    # subnets          = aws_subnet.public_subnets[*].id
    # assign_public_ip = true

    security_groups = [aws_security_group.ecs_service.id]

    subnets          = aws_subnet.private_subnets[*].id
    assign_public_ip = false

  }

  # Enable ECS Exec
  enable_execute_command = true

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg.arn
    container_name   = "nginx"
    container_port   = 80
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_exec_attach_managed,
  ]
}

# ECS Service Security Group
resource "aws_security_group" "ecs_service" {
  name        = "${local.prefix}-ecs-sg"
  description = "Allow HTTP inbound traffic to ECS service"
  vpc_id      = aws_vpc.main.id
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    # cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
