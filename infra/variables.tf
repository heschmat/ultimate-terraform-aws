variable "project_name" {
  default = "watchlist-api"
}

variable "contact_email" {
  default = "heschmatx@gmail.com"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "state_bucket" {
  default = "watchlist-api-state-bucket"
}

# network variables ======================= #
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  default = ["10.0.10.0/24", "10.0.20.0/24"]

}

# rds variables ========================== #
variable "db" {
  default = {
    engine_version    = "17.2"
    allocated_storage = 20
    storage_type      = "gp3"
    instance_class    = "db.t3.micro"
    username          = "admino"
    db_name           = "watchlistdb"
  }

  type = object({
    allocated_storage = number
    storage_type      = string
    instance_class    = string
    username          = string
    db_name           = string
    engine_version    = string
  })
}

variable "db_password" {
  default = "#SuperSecret123"

}

# ec2 variables ========================= #
variable "instance_type" {
  default = "t3.micro"
}
