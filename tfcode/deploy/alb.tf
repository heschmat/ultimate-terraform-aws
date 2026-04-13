resource "aws_security_group" "alb" {
  name        = "${local.prefix}-alb-sg"
  description = "Security group for ALB, allowing inbound HTTP from anywhere and outbound to ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }
}

resource "aws_lb" "ecs" {
  name               = "${local.prefix}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public.*.id

  tags = {
    Name = "${local.prefix}-alb"
  }
}

resource "aws_lb_target_group" "ecs" {
  name     = "${local.prefix}-tg"
  port     = var.container_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # Because we're using awsvpc network mode for our ECS tasks,
  # we need to set the target type to "ip" and the ALB will route traffic directly to the task ENIs.
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${local.prefix}-tg"
  }
}

# Listener for ALB to forward HTTP traffic to the target group
# flow is: ALB (port 80) -> Target Group (port 80) -> ECS tasks (port 80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ecs.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }
}
