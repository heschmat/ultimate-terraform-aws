# exec role -----
# This one is needed so ECS can pull images, write logs, and fetch secrets later.
resource "aws_iam_role" "ecs_exec_role" {
  name               = "ecs-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_role_assume_role_policy.json
}

# attach the AmazonECSTaskExecutionRolePolicy to allow ECS tasks to execute commands via SSM.
resource "aws_iam_role_policy_attachment" "ecs_exec_role_ssm_core" {
  role       = aws_iam_role.ecs_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# task role -----
resource "aws_iam_role" "ecs_task_role" {
  name               = "ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_role_assume_role_policy.json
}


# # attach the AmazonSSMManagedInstanceCore policy to allow ECS tasks to execute commands via SSM.
# resource "aws_iam_role_policy_attachment" "ecs_task_role_ssm_core" {
#   role       = aws_iam_role.ecs_task_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }

resource "aws_iam_role_policy" "ecs_task_exec_command" {
  name = "${local.prefix}-ecs-exec-command"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

# ECS cluster -----
resource "aws_ecs_cluster" "main" {
  name = "${local.prefix}-ecs-cluster"

  tags = {
    Name = "${local.prefix}-ecs-cluster"
  }
}

# log group for ECS tasks
resource "aws_cloudwatch_log_group" "ecs_tasks" {
  name              = "/ecs/${local.prefix}-tasks"
  retention_in_days = 7
  tags = {
    Name = "/ecs/${local.prefix}-tasks"
  }
}

# Security group for ECS tasks -----
resource "aws_security_group" "ecs_tasks" {
  name        = "${local.prefix}-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.prefix}-ecs-tasks-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_http" {
  security_group_id            = aws_security_group.ecs_tasks.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ec2_ssm_sg.id
}

resource "aws_vpc_security_group_egress_rule" "ecs_all_out" {
  security_group_id = aws_security_group.ecs_tasks.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Task definition -----
resource "aws_ecs_task_definition" "app" {
  family                   = "${local.prefix}-${var.app_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)
  execution_role_arn       = aws_iam_role.ecs_exec_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_tasks.name
          awslogs-region        = data.aws_region.current.id
          awslogs-stream-prefix = var.app_name
        }
      }
    }
  ])
}

# ECS service -----
resource "aws_ecs_service" "app" {
  name            = "${local.prefix}-${var.app_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # IMPORTANT: enable execute command to allow us to run commands in the ECS tasks via SSM.
  enable_execute_command = true

  network_configuration {
    subnets = [for s in aws_subnet.private : s.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  tags = {
    Name = "${local.prefix}-${var.app_name}-service"
  }
}
