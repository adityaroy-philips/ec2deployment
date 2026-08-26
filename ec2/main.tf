# 1. Create the Custom VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "ssm-windows-vpc" }
}

# 2. Internet Gateway for Public Routing
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "main-igw" }
}

# 3. Create Subnets
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "public-subnet" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.20.2.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "private-subnet" }
}

# 4. Elastic IP and NAT Gateway for Private Subnet Outbound Internet
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags          = { Name = "main-nat-gw" }
}

# 5. Route Tables & Associations
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "private-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# 6. IAM Instance Profile for Systems Manager (SSM)
resource "aws_iam_role" "ssm_role" {
  name = "WindowsEC2SSMRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "windows_ec2_ssm_profile"
  role = aws_iam_role.ssm_role.name
}

# 7. Security Group (No Inbound rules needed for SSM Session Manager!)
resource "aws_security_group" "ec2_sg" {
  name        = "windows-private-sg"
  description = "Egress only security group for private windows ec2"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_block  = ["0.0.0.0/0"]
  }
  tags = { Name = "windows-private-sg" }
}

# 8. Fetch Latest Windows Server 2022 AMI
data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
}

# 9. Launch Windows EC2 Instance in Private Subnet
resource "aws_instance" "windows_server" {
  ami                  = data.aws_ami.windows.id
  instance_type        = "t3.medium" # Minimum recommended sizing for Windows Server
  subnet_id            = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  instance_profile     = aws_iam_instance_profile.ec2_profile.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # Enforce IMDSv2 security
  }

  tags = { Name = "Private-Windows-Server" }
}
