resource "aws_db_subnet_group" "name" {
  name = "${local.prefix}-db-subnet-group"
  # subnet_ids = aws_subnet.private[*].id

  subnet_ids = [for subnet in aws_subnet.private : subnet.id]

  tags = {
    Name = "${local.prefix}-db-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  name        = "${local.prefix}-rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_db_instance" "rds_pg" {
  identifier                 = "${local.prefix}-rds-pg"
  engine                     = "postgres"
  engine_version             = var.db.engine_version
  auto_minor_version_upgrade = true
  allocated_storage          = var.db.allocated_storage
  storage_type               = var.db.storage_type


  instance_class         = var.db.instance_class
  db_subnet_group_name   = aws_db_subnet_group.name.name
  vpc_security_group_ids = [aws_security_group.rds.id]


  db_name  = var.db.db_name
  username = var.db.username
  password = var.db_password

  skip_final_snapshot     = true # Set to true for development, but should be false in production to avoid data loss.
  publicly_accessible     = false
  multi_az                = false # Set to true for production for high availability, but false for development to save costs.
  deletion_protection     = false # Set to true in production to prevent accidental deletion, but false for development.
  storage_encrypted       = true
  backup_retention_period = 7    # Retain backups for 1 days, adjust as needed.
  apply_immediately       = true # Apply changes immediately for development, but consider setting to false in production to avoid downtime.

  tags = {
    Name = "${local.prefix}-rds-pg"
  }
}

# Output the RDS endpoint and credentials ===== #
output "rds_endpoint" {
  value = aws_db_instance.rds_pg.address
}
