terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # ~> 6.0 → pin major (only 6.x.x)
      # ~> 6.2 → pin minor (only 6.2.x)
      # ~> 6.2.3 → pin patch floor, allow patch upgrades
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
    # S3 URI: s3://watchlist-api-state-bucket/environ/<WS>/deploy/terraform.tfstate
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
