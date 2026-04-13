data "aws_region" "current" {}

# terraform console 
# data.aws_region.current.name
# # known after apply

data "aws_availability_zones" "available" {
  state = "available"
}


# Amazon Linux 2023 is the modern replacement for Amazon Linux 2.
# For almost all new infrastructure, you should choose AL2023.
# Also, the SSM Agent is already preinstalled in AL2023,
# so we mainly need an IAM role + outbound HTTPS access.
data "aws_ami" "amazon_linux_2023" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# For ECS, we need to create an IAM role that the ECS tasks can assume to allow them to execute commands.
data "aws_iam_policy_document" "ecs_role_assume_role_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}
