variable "project_name" {
  type = string

}

variable "contact_email" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket" {
  type = string
}

# network variables
variable "vpc_cidr" {
  type = string
  # default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type = list(string)
  # default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  type = list(string)
  # default = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
}
# variable "availability_zones" {
#   type    = list(string)
#   default = ["us-east-1a", "us-east-1b", "us-east-1c"]
# }

variable "my_public_ip" {
  type = string
}

# RDS variables ======================= #
variable "rds_db_name" {
  type = string
  # default = "mydatabase"
}

variable "rds_username" {
  type = string
  # default = "dbadmin"
}

variable "rds_password" {
  type      = string
  sensitive = true
  # default = "ChangeMe123!"
}

# application variables ======================= #