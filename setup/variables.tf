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

variable "environ" {
  type    = string
  default = "dev"
}
