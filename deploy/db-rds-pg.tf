# create subnet group for RDS
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${local.prefix}-rds-subnet-group"
  subnet_ids = aws_subnet.private_subnets[*].id
  tags = {
    Name = "${local.prefix}-rds-subnet-group"
  }
}

# create security group for RDS
resource "aws_security_group" "rds_sg" {
  name   = "${local.prefix}-rds-sg"
  vpc_id = aws_vpc.main.id
  # Allow inbound Postgres access from the application security group
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # (dev only) allow from inside VPC; for more restriction, specify app SG
  }
  # Allow outbound internet access for updates, etc.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.prefix}-rds-sg"
  }
}

# create the RDS Postgres instance
resource "aws_db_instance" "rds_postgres" {
  identifier                 = "${local.prefix}-rds-pg"
  allocated_storage          = 20
  engine                     = "postgres"
  engine_version             = "18.1"
  auto_minor_version_upgrade = true

  instance_class = "db.t3.micro"
  db_name        = var.rds_db_name
  username       = var.rds_username
  password       = var.rds_password

  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  skip_final_snapshot     = true
  publicly_accessible     = false
  multi_az                = false
  deletion_protection     = false
  storage_encrypted       = true
  backup_retention_period = 7
  apply_immediately       = true
  tags = {
    Name = "${local.prefix}-rds-pg"
  }
}

# output the RDS endpoint
output "rds_postgres_endpoint" {
  value = aws_db_instance.rds_postgres.endpoint
}

# output the RDS instance address
output "rds_postgres_address" {
  value = aws_db_instance.rds_postgres.address
}

# output the RDS instance identifier
output "rds_postgres_identifier" {
  value = aws_db_instance.rds_postgres.identifier
}
