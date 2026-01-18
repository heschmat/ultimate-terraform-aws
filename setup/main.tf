terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "watchlist-api-state-bucket"
    region       = "us-east-1"
    key          = "setup-key"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = terraform.workspace
      ProjectName = var.project_name
      Contact     = var.contact_email
      ManagedBy   = "Terraform/setup"
    }
  }
}
