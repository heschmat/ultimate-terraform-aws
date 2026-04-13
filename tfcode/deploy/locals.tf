
locals {
  prefix = "${var.project_name}-${terraform.workspace}"

  #   # Since for_each works best with a map or set, we can build a map that pairs each subnet CIDR with an AZ.
  #   # since we have only 2 AZs, we can hardcode the mapping here
  #   # in a real project, you might want to make this more dynamic
  #   private_subnets = {
  #     private_a = {
  #       cidr = var.private_subnet_cidrs[0]
  #       az   = data.aws_availability_zones.available.names[0]
  #     }
  #     private_b = {
  #       cidr = var.private_subnet_cidrs[1]
  #       az   = data.aws_availability_zones.available.names[1]
  #     }
  #   }

  private_subnets = {
    for i, cidr in var.private_subnet_cidrs :
    "private_${i + 1}" => {
      cidr = cidr
      az   = data.aws_availability_zones.available.names[i]
    }
  }

  # resources using count are accessed by numeric index, starting from 0.
  postgres_instance = var.is_production ? aws_db_instance.postgres_prod[0] : aws_db_instance.postgres[0]
}
