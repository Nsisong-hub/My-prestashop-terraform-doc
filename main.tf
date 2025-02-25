

# Configure the AWS Provider and set the region to us-east-1
provider "aws" {
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "Prestashop-VPC"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Prestashop-Internet-Gateway"
  }
}

# Create a public subnet 1
resource "aws_subnet" "public_subnet1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"  
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "Prestashop-Public-Subnet1"
  }
}

# Create a public subnet 2
resource "aws_subnet" "public_subnet2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"  
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"  # Ensure a different AZ
  tags = {
    Name = "Prestashop-Public-Subnet2"
  }
}

# Create Private Subnet 1
resource "aws_subnet" "private_subnet1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Prestashop-Private-Subnet1"
  }
}

# Create Private Subnet 2
resource "aws_subnet" "private_subnet2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "Prestashop-Private-Subnet2"
  }
}


# Create a Route Table and Associate it with the Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "Prestashop-Public-Route-Table"
  }
}

resource "aws_route_table_association" "public_subnet1" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_subnet2" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public.id
}

# Security Group for EC2 Instance
resource "aws_security_group" "ec2" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Prestashop-EC2-SG"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public_subnet1.cidr_block, aws_subnet.public_subnet2.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Prestashop-RDS-SG"
  }
}

# Create an RDS MySQL Database
resource "aws_db_instance" "mysql" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  db_name              = "prestashopdb"
  username             = "admin"
  password             = "Password123"  # Replace with your password
  publicly_accessible  = false
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name = aws_db_subnet_group.main.name

#Skip final snapshot to avoid error
  skip_final_snapshot = true  

}

# Create an RDS DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "prestashop-rds-subnet-group"
  subnet_ids = [
    aws_subnet.private_subnet1.id,
    aws_subnet.private_subnet2.id
  ]
  tags = {
    Name = "Prestashop-RDS-Subnet-Group"
  }
}

# Create an EC2 Instance
resource "aws_instance" "prestashop" {
  ami           = "ami-04b4f1a9cf54c11d0"  # Update with the correct AMI for Ubuntu in us-east-1
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet1.id
  security_groups = [aws_security_group.ec2.id]
  key_name      = "mykeypair"  # Replace with your key pair namec


  user_data = file("scripts/install-docker.sh")  # Install Docker and PrestaShop

  tags = {
    Name = "Prestashop-EC2"
  }

}


