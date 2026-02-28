resource "aws_security_group" "private_instance" {
  name   = "${local.prefix}-private-instance-sg"
  vpc_id = aws_vpc.main.id

  # no ingress rules, as this SG will be used for private instances that don't need to accept inbound traffic from the internet

  # allow all outbound traffic so instances can access the internet for updates, etc.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "private_instance" {
  name = "${local.prefix}-private-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "private_instance_ssm" {
  role       = aws_iam_role.private_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "private_instance" {
  name = "${local.prefix}-private-instance-profile"
  role = aws_iam_role.private_instance.name
}

resource "aws_instance" "private_instance" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private[0].id
  associate_public_ip_address = false

  vpc_security_group_ids = [aws_security_group.private_instance.id]
  # This instance profile allows the EC2 instance to use the SSM agent to connect to Systems Manager, which is necessary for private instances that don't have direct internet access.
  iam_instance_profile = aws_iam_instance_profile.private_instance.name

  # install the SSM agent and create a simple file to verify connectivity via SSM Session Manager
  # install also utils like curl, psql-client, etc. as needed for your use case
  # user_data = <<-EOF
  #             #!/bin/bash
  #             apt-get update -y
  #             apt-get install -y amazon-ssm-agent postgresql-client curl
  #             systemctl enable amazon-ssm-agent
  #             systemctl start amazon-ssm-agent
  #             echo "SSM agent installed and running" > /tmp/ssm_test.txt
  #           EOF
  # user_data = <<-EOF
  #             #!/bin/bash
  #             set -e

  #             apt-get update -y
  #             apt-get install -y postgresql-client curl

  #             echo "User data completed" > /tmp/user_data_done.txt
  #           EOF
  user_data = <<-EOF
    #cloud-config
    package_update: true
    packages:
      - postgresql-client
    runcmd:
      - echo "done" > /tmp/user_data_done.txt
    EOF

  user_data_replace_on_change = true

  tags = {
    Name = "${local.prefix}-private-instance"
  }
}

# Output the private instance ID and public IP (which will be null since it's in a private subnet) ===== #
output "private_instance_id" {
  value = aws_instance.private_instance.id
}


# sudo apt install postgresql-client -y