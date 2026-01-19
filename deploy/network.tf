# create aws vpc
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.prefix}-vpc"
  }
}

# igw for public subnets
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.prefix}-igw"
  }
}

# route table for public subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.prefix}-public-rt"
  }
}

# route to igw for public subnets
resource "aws_route" "public_rt_igw_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# create public subnets
resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "${local.prefix}-public-subnet-${count.index + 1}"
    Tier = "public"
  }
}

# associate public subnets with public route table
resource "aws_route_table_association" "public_subnet_associations" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# private subnets ========================== #
# for private subnets we require the following:
# - private subnets
# - nat gateway in each public subnet (for high availability)
# - elastic ip for each nat gateway
# - route table for private subnets
# - route to nat gateway in private route table
# - association of private subnets with private route table 
# why do we need association of private subnets with private route table?
# because by default, subnets are associated with the main route table of the VPC
# and we want to override that association to use our custom private route table

resource "aws_eip" "nat" {
  count  = length(aws_subnet.public_subnets)
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  count         = length(aws_subnet.public_subnets)
  subnet_id     = aws_subnet.public_subnets[count.index].id
  allocation_id = aws_eip.nat[count.index].id
}

# private route tables (one per AZ)
resource "aws_route_table" "private" {
  count  = length(aws_nat_gateway.nat)
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.prefix}-private-rt-${count.index + 1}"
  }
}


# route to nat gateway for private route tables
resource "aws_route" "private_nat" {
  count                  = length(aws_route_table.private)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[count.index].id
}


resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "${local.prefix}-private-subnet-${count.index + 1}"
    Tier = "private"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private_subnets)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# End of private subnets =================== #
