
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# ec2 ===============
# The Amazon Linux 2023 minimal AMI does NOT include the SSM agent.

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    # values = ["al2023-ami-*-x86_64"]
    # Full AL2023 AMIs do not contain -minimal- in this position:
    values = ["al2023-ami-2023.*-x86_64"]
  }

}

## ecs ===============

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}
