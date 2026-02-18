resource "aws_vpc" "main" {
  cidr_block       = var.cidr_block
  instance_tenancy = var.instance_tenancy

  tags = {
  Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
  Name = "${local.name_prefix}-subnet"
  }
}

resource "aws_internet_gateway" "igw01" {
  vpc_id = aws_vpc.main.id

  tags = {
  Name = "${local.name_prefix}-igw"
  }
}

resource "aws_route_table" "rt01" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw01.id
  }

  tags = {
  Name = "${local.name_prefix}-route-table"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.rt01.id
}