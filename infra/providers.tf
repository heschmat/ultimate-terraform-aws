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
