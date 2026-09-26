data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az = data.aws_availability_zones.available.names[0]
}

# DNS hostnames and support on: each instance gets a private DNS name
# (ip-10-240-1-23.ec2.internal), and that is what the node name must match.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_id}-vpc"
  }
}

# Public subnet: bastion, NAT gateway, API load balancer. External Service load balancers go here.
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 0) # 10.240.0.0/24
  availability_zone = local.az

  tags = {
    Name                                      = "${var.cluster_id}-public"
    "kubernetes.io/cluster/${var.cluster_id}" = "owned"
    "kubernetes.io/role/elb"                  = "1"
  }
}

# Private subnet: control plane and workers, no public IPs. Internal Service load balancers go here.
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1) # 10.240.1.0/24
  availability_zone = local.az

  tags = {
    Name                                      = "${var.cluster_id}-private"
    "kubernetes.io/cluster/${var.cluster_id}" = "owned"
    "kubernetes.io/role/internal-elb"         = "1"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_id}-igw"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.cluster_id}-nat"
  }
}

# Lets the private instances pull images without a public IP of their own.
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${var.cluster_id}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.cluster_id}-public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.cluster_id}-private"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
