# # IAM roles for ECS tasks and execution role ===== #
# resource "aws_iam_role" "ecs_execution_role" {
#   name = "${local.prefix}-ecs-execution-role"
#   assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
# }

# resource "aws_iam_role_policy_attachment" "ecs_execution_role_attachment" {
#   role       = aws_iam_role.ecs_execution_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
# }

# resource "aws_iam_role" "ecs_task_role" {
#   name = "${local.prefix}-ecs-task-role"
#   assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
# }

# resource "aws_iam_role_policy_attachment" "ecs_task_ssm" {
#     role       = aws_iam_role.ecs_task_role.name
#     policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
# }

# # ECS Cluster ========================= #
# resource "aws_ecs_cluster" "main" {
#   name = "${local.prefix}-cluster"

#   tags = {
#     Name        = "${local.prefix}-cluster"
#   }
# }

# # ECS log group ======================= #
# resource "aws_cloudwatch_log_group" "ecs" {
#   name              = "/ecs/${local.prefix}"
#   retention_in_days = 7

#   tags = {
#     Name = "/ecs/${local.prefix}"
#   }
# }

# # ECS capacity provider with auto-scaling group ======== #
# resource "aws_autoscaling_group" "ecs_capacity_provider_asg" {
#   name                      = "${local.prefix}-ecs-asg"
#   max_size                  = 2
#   min_size                  = 0
#   desired_capacity          = 1
#   vpc_zone_identifier       = aws_subnet.public.*.id
#   launch_template {
#     id      = aws_launch_template.ecs_capacity_provider_lt.id
#     version = "$Latest"
#   }
#   lifecycle {
#     create_before_destroy = true
#   }
# }

# # ECS launch template for capacity provider ================== #
# resource "aws_launch_template" "ecs_capacity_provider_lt" {
#   name_prefix   = "${local.prefix}-ecs-lt-"
#   image_id      = data.aws_ami.ubuntu.id
#   instance_type = var.instance_type
#     iam_instance_profile {
#         name = aws_iam_instance_profile.ecs_instance_profile.name
#     }
#     user_data = <<-EOF
#                 #!/bin/bash
#                 echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
#                 EOF
# }

# resource "aws_iam_instance_profile" "ecs_instance_profile" {
#   name = "${local.prefix}-ecs-instance-profile"
#   role = aws_iam_role.ecs_execution_role.name
# }

# resource "aws_ecs_capacity_provider" "main" {
#   name = "${local.prefix}-capacity-provider"

#   auto_scaling_group_provider {
#     auto_scaling_group_arn = aws_autoscaling_group.ecs_capacity_provider_asg.arn

#     managed_scaling {
#       status                    = "ENABLED"
#       target_capacity           = 100
#       minimum_scaling_step_size = 1
#       maximum_scaling_step_size = 1000
#     }
#   }
# }

# # Attach capacity provider to ECS cluster =============== #
# resource "aws_ecs_cluster_capacity_providers" "main" {
#   cluster_name = aws_ecs_cluster.main.name
#   capacity_providers = [aws_ecs_capacity_provider.main.name]
#   default_capacity_provider_strategy {
#     capacity_provider = aws_ecs_capacity_provider.main.name
#     weight            = 1
#   }
# }

# # ECS service ========================= #
# resource "aws_ecs_service" "main" {
#   name            = "${local.prefix}-service"
#   cluster         = aws_ecs_cluster.main.id
#   task_definition = aws_ecs_task_definition.main.arn
#   desired_count   = 1
#   launch_type     = "EC2"
#     depends_on = [aws_ecs_cluster_capacity_providers.main]
#     tags = {
#     Name = "${local.prefix}-service"
#   }
# }

# # ECS task definition ========================= #
# resource "aws_ecs_task_definition" "main" {
#   family                   = "${local.prefix}-task"
#   network_mode             = "awsvpc"
#   requires_compatibilities = ["FARGATE"]
#   execution_role_arn       = aws_iam_role.ecs_execution_role.arn
#     task_role_arn            = aws_iam_role.ecs_task_role.arn
#     container_definitions    = jsonencode([
#         {
#         name      = "watchlist-api"
#         image     = "heschmatx/watchlist-api:latest"
#         essential = true
#         portMappings = [
#             {
#             containerPort = 8080
#             hostPort      = 8080
#             protocol      = "tcp"
#             }
#         ]
#         logConfiguration = {
#             logDriver = "awslogs"
#             options = {
#             "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
#             "awslogs-region"        = data.aws_region.current.name
#             "awslogs-stream-prefix" = "ecs"
#             }
#         }
#         }
#     ])
# }

# # ECS service autoscaling ========================= #
# resource "aws_appautoscaling_target" "ecs_service" {
#   max_capacity       = 2
#   min_capacity       = 1
#   resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
#   scalable_dimension = "ecs:service:DesiredCount"
#   service_namespace  = "ecs"
# }

# resource "aws_appautoscaling_policy" "ecs_service_cpu" {
#   name               = "${local.prefix}-cpu-scaling-policy"
#   policy_type        = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.ecs_service.resource_id
#   scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
#   service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

#   target_tracking_scaling_policy_configuration {
#     target_value       = 50.0
#     predefined_metric_specification {
#       predefined_metric_type = "ECSServiceAverageCPUUtilization"
#     }
#     scale_out_cooldown  = 60
#     scale_in_cooldown   = 60
#   }
# }


# # Add a scaling policy for memory utilization
# resource "aws_appautoscaling_policy" "ecs_service_memory" {
#   name               = "${local.prefix}-memory-scaling-policy"
#   policy_type        = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.ecs_service.resource_id
#   scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
#   service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

#   target_tracking_scaling_policy_configuration {
#     target_value       = 50.0
#     predefined_metric_specification {
#       predefined_metric_type = "ECSServiceAverageMemoryUtilization"
#     }
#     scale_out_cooldown  = 60
#     scale_in_cooldown   = 60
#   }
# }

# # Add tags to ECS service autoscaling policies
# resource "aws_appautoscaling_policy" "ecs_service_cpu" {
#   name               = "${local.prefix}-cpu-scaling-policy"
#   policy_type        = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.ecs_service.resource_id
#   scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
#   service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

#     target_tracking_scaling_policy_configuration {
#         target_value       = 50.0
#         predefined_metric_specification {
#         predefined_metric_type = "ECSServiceAverageCPUUtilization"
#         }
#         scale_out_cooldown  = 60
#         scale_in_cooldown   = 60
#     }
#     tags = {
#         Name = "${local.prefix}-cpu-scaling-policy"
#     }
# }


# resource "aws_appautoscaling_policy" "ecs_service_memory" {
#   name               = "${local.prefix}-memory-scaling-policy"
#   policy_type        = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.ecs_service.resource_id
#   scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
#   service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

#     target_tracking_scaling_policy_configuration {
#         target_value       = 50.0
#         predefined_metric_specification {
#         predefined_metric_type = "ECSServiceAverageMemoryUtilization"
#         }
#         scale_out_cooldown  = 60
#         scale_in_cooldown   = 60
#     }
#     tags = {
#         Name = "${local.prefix}-memory-scaling-policy"
#     }
# }


# # Output the ECS cluster name and service name for reference
# output "ecs_cluster_name" {
#   value = aws_ecs_cluster.main.name
# }

# output "ecs_service_name" {
#   value = aws_ecs_service.main.name
# }

