locals {
  prefix = "${var.project_name}-${terraform.workspace}"
}

locals {
  public_subnets = {
    subnet1 = {
      cidr = element(var.public_subnet_cidrs, 0)
      az   = data.aws_availability_zones.available.names[0]
    }
    subnet2 = {
      cidr = element(var.public_subnet_cidrs, 1)
      az   = data.aws_availability_zones.available.names[1]
    }
  }
}
