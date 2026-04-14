# IAM Role and Instance Profile for EC2 to use SSM

resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ec2_read_rds_secret" {
  name = "${local.prefix}-ec2-read-rds-secret"
  role = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        # Error: Missing resource instance key
        # Because aws_db_instance.postgres has "count" set, its attributes must be accessed on specific instances.
        # Resource = aws_db_instance.postgres.master_user_secret[0].secret_arn

        Resource = local.postgres_instance.master_user_secret[0].secret_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_read_ecs" {
  name = "${local.prefix}-ec2-read-ecs"
  role = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:ListClusters",
          "ecs:DescribeClusters",
          "ecs:ListServices",
          "ecs:DescribeServices",
          "ecs:ListTasks",
          "ecs:DescribeTasks",
          "ecs:DescribeTaskDefinition",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# Security Group for EC2 instances to allow outbound HTTPS for SSM
# For SSM, we do NOT need inbound port 22.
# SSM only needs outbound 443 to communicate with the SSM endpoints.
# resource "aws_security_group" "ec2_ssm_sg" {
#   name        = "ec2-ssm-sg"
#   description = "Allow outbound HTTPS for SSM"
#   vpc_id      = aws_vpc.main.id

#   # outbound for SSM and Secrets Manager
#   egress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   # outbound only to the RDS SG
#   # Because security groups are stateful, 
#   # we do not need a matching inbound rule on the EC2 SG for the return traffic from RDS.
#   egress {
#     from_port       = 5432
#     to_port         = 5432
#     protocol        = "tcp"
#     # ⚠️Error: Cycle: aws_security_group.ec2_ssm_sg, aws_security_group.rds_postgres
#     # security_groups = [aws_security_group.rds_postgres.id]
#   }
# }

resource "aws_security_group" "ec2_ssm_sg" {
  name        = "${local.prefix}-ec2-ssm-sg"
  description = "SSM box security group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.prefix}-ec2-ssm-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "ec2_https_out" {
  security_group_id = aws_security_group.ec2_ssm_sg.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "ec2_to_rds_postgres" {
  security_group_id            = aws_security_group.ec2_ssm_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.rds_postgres.id
}

# ⚠️ otherwise: 
# sh-5.2$ curl -i $PRIVATE_IP
# curl: (28) Failed to connect to 10.0.102.29 port 80 after 131292 ms: Could not connect to server
resource "aws_vpc_security_group_egress_rule" "ec2_to_ecs_http" {
  security_group_id            = aws_security_group.ec2_ssm_sg.id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = aws_security_group.ecs_tasks.id
}

# EC2 instance to test SSM connectivity
resource "aws_instance" "ssm_box" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private["private_1"].id
  vpc_security_group_ids = [aws_security_group.ec2_ssm_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name

  user_data_replace_on_change = true

  # user_data = <<-EOF
  #   #!/bin/bash
  #   set -euxo pipefail

  #   dnf update -y
  #   dnf install -y jq nmap-ncat postgresql17
  # EOF

  user_data = file("${path.module}/user_data.sh")

  tags = {
    Name = "${local.prefix}-ssm-box"
  }
}
