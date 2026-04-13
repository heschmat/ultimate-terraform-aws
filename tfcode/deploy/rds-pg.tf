# AWS requires a DB subnet group for RDS in a VPC, and recommends subnets in at least two AZs. 
# Private subnet groups are the standard way to keep the DB internal-only.
resource "aws_db_subnet_group" "postgres" {
  name       = "${local.prefix}-postgres-subnet-group"
  subnet_ids = [for s in aws_subnet.private : s.id]

  tags = {
    Name = "${local.prefix}-postgres-subnet-group"
  }
}

# resource "aws_security_group" "rds_postgres" {
#   name        = "${local.prefix}-rds-postgres-sg"
#   description = "Allow PostgreSQL from EC2 SSM box"
#   vpc_id      = aws_vpc.main.id

#   ingress {
#     from_port = 5432
#     to_port   = 5432
#     protocol  = "tcp"
#     security_groups = [
#       aws_security_group.ec2_ssm_sg.id,
#     ]
#   }

#   tags = {
#     Name = "${local.prefix}-rds-postgres-sg"
#   }
# }

resource "aws_security_group" "rds_postgres" {
  name        = "${local.prefix}-rds-postgres-sg"
  description = "Allow PostgreSQL from EC2 SSM box"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.prefix}-rds-postgres-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ec2_postgres" {
  security_group_id            = aws_security_group.rds_postgres.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.ec2_ssm_sg.id
}

resource "aws_db_instance" "postgres" {
  count = var.is_production ? 0 : 1

  identifier = "${local.prefix}-postgres"

  engine         = "postgres"
  engine_version = var.db.engine_version
  instance_class = var.db.instance_class

  allocated_storage     = var.db.allocated_storage
  max_allocated_storage = var.db.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db.name
  username = var.db.username
  #   password = var.db_password
  port = 5432

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds_postgres.id]
  publicly_accessible    = false

  backup_retention_period = var.db.backup_retention_days
  skip_final_snapshot     = true  # For non-production, we can skip the final snapshot to allow easier cleanup. For production, we want to keep it.
  deletion_protection     = false # For non-production, we allow deletion for easier cleanup. For production, we want to prevent accidental deletion.
  multi_az                = false # For non-production, we can save costs by not using Multi-AZ. For production, we want high availability with Multi-AZ.
  apply_immediately       = true  # For non-production, we want changes to apply immediately for faster iteration. For production, we also want changes to apply immediately to minimize downtime.

  auto_minor_version_upgrade = true

  tags = {
    Name = "${local.prefix}-postgres"
  }

}


resource "aws_db_instance" "postgres_prod" {
  count = var.is_production ? 1 : 0

  identifier = "${local.prefix}-postgres"

  engine         = "postgres"
  engine_version = var.db.engine_version
  instance_class = var.db.instance_class

  allocated_storage     = var.db.allocated_storage
  max_allocated_storage = var.db.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db.name
  username = var.db.username
  port     = 5432

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds_postgres.id]
  publicly_accessible    = false

  backup_retention_period   = var.db.backup_retention_days
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.prefix}-postgres-final"

  multi_az                   = true # For production, we want high availability with Multi-AZ
  apply_immediately          = true # For production, we want changes to apply immediately to minimize downtime
  auto_minor_version_upgrade = true

  tags = {
    Name = "${local.prefix}-postgres"
    Tier = "production"
  }

  # For a production database, we want to prevent accidental deletion.
  # For non-production, we allow it for easier cleanup.

  lifecycle {
    prevent_destroy = true
  }
}
