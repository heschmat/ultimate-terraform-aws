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

# An error occurred (TargetNotConnectedException)
# when calling the ExecuteCommand operation: The execute command failed due to an internal error.
resource "aws_iam_role_policy_attachment" "ecs_task_ssm" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
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
      # name      = "nginx"
      # image     = "nginx:alpine"
      # essential = true

      # portMappings = [
      #   {
      #     containerPort = 80
      #     hostPort      = 80
      #     protocol      = "tcp"
      #   }
      # ]

      name      = "api"
      image     = var.app_image
      essential = true

      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "DJANGO_ALLOW_ASGI_HOST", value = "true" },
        { name = "DEBUG", value = "0" },
        { name = "DJANGO_SECRET_KEY", value = var.django_secret_key },
        # Database settings
        { name = "DB_NAME", value = var.db.db_name },
        { name = "DB_USER", value = var.db.username },
        { name = "DB_PASS", value = var.db_password },
        { name = "DB_HOST", value = aws_db_instance.rds_postgres.address },
        { name = "DB_PORT", value = tostring(aws_db_instance.rds_postgres.port) },
        # S3 settings
        { name = "AWS_STORAGE_BUCKET_NAME", value = aws_s3_bucket.static.bucket },
        { name = "AWS_S3_REGION_NAME", value = var.aws_region },
        { name = "CLOUDFRONT_DOMAIN", value = aws_cloudfront_distribution.static.domain_name },
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
    # container_name   = "nginx"
    # container_port   = 80
    container_name = "api"
    container_port = 8000
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
    from_port   = 8000
    to_port     = 8000
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
