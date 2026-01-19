terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket               = "watchlist-api-state-bucket"
    key                  = "deploy/terraform.tfstate"
    region               = "us-east-1"
    encrypt              = true
    use_lockfile         = true
    workspace_key_prefix = "environ"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = terraform.workspace
      ProjectName = var.project_name
      Contact     = var.contact_email
      ManagedBy   = "Terraform/deploy"
    }
  }
}
