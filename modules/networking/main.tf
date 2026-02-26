resource "aws_vpc" "main" {
  cidr_block       = var.cidr_block
  instance_tenancy = var.instance_tenancy

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}
resource "aws_flow_log" "vpc_flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_logs[0].arn
  iam_role_arn         = aws_iam_role.flow_log_role[0].arn
}
#To see logs of which ip connected to which port and protocol, and whether the traffic was accepted or rejected. This is crucial for monitoring and troubleshooting network issues, as well as for security auditing.
#Enforeced by Tfsec

resource "aws_cloudwatch_log_group" "vpc_logs" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/${local.name_prefix}-flow-logs"
  retention_in_days = var.flow_log_retention_days
}

resource "aws_iam_role" "flow_log_role" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${local.name_prefix}-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flow_log_policy" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${local.name_prefix}-flow-log-policy"
  role = aws_iam_role.flow_log_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidr_block
  availability_zone = var.availability_zone
  # tfsec:ignore:aws-ec2-no-public-ip-subnet
  # Public subnet required for internet-facing NGINX ingress
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