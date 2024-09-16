# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "eks-vpc"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = var.internet_accessible
  availability_zone       = "us-west-2a"
  tags = {
    Name = "eks-public-subnet"
  }
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "us-west-2a"
  tags = {
    Name = "eks-private-subnet"
  }
}

# Conditionally create Internet Gateway
resource "aws_internet_gateway" "igw" {
  count  = var.internet_accessible ? 1 : 0
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "eks-igw"
  }
}

# Conditionally create Route Table
resource "aws_route_table" "public" {
  count  = var.internet_accessible ? 1 : 0
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw[0].id
  }

  tags = {
    Name = "eks-public-route-table"
  }
}

# Conditionally create Route Table Association
resource "aws_route_table_association" "public" {
  count          = var.internet_accessible ? 1 : 0
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public[0].id
}
