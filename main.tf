# Configure the AWS Provider
provider "aws" {
  region     = "us-east-2"
  access_key = "your-access-id"
  secret_key = "your-secret-key"
}

#configure the aws resources
/*
resource "provider_resourceType" "name" {
    config opitions
    key = "value"
    .
    .
    .
    .
}
*/
/* Terraform project
1. Create VPC
2. Create a Internal gateway
3. Create  Custom Route Table
4. Create Subnet
5. Associate Subnet with a route table
6. Create security group to allow port 22, 80, 443
7. Create a network interface with an Ip in the subnet that was created in step 4
8. Assign an elastic IP to the network interface created in step 7
9. Create Ubuntu Server and install/enable apache2
*/

#1. Create VPC
resource "aws_vpc" "vpc-1" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "prod_vpc"
  }
}

#2. Create a Internal gateway
resource "aws_internet_gateway" "igw-1" {
  vpc_id = aws_vpc.vpc-1.id

  tags = {
    Name = "prod_gw"
  }
}

#3. Create  Custom Route Table
resource "aws_route_table" "route-table-1" {
  vpc_id = aws_vpc.vpc-1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-1.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.igw-1.id
  }

  tags = {
    Name = "prod_rt"
  }
}


#4. Create Subnet
resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.vpc-1.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "prod_subnet"
  }
}

#5. Associate Subnet with a route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.route-table-1.id
}

#6. Create security group to allow port 22, 80, 443
resource "aws_security_group" "security-group-1" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.vpc-1.id

  ingress {
    description = "allow_443"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow_22"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow_80"
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
    Name = "prod_sg"
  }
}

#7. Create a network interface with an Ip in the subnet that was created in step 4
resource "aws_network_interface" "test" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.security-group-1.id]
}

#8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.test.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.igw-1]
}


#9. Create Ubuntu Server and install/enable apache2
resource "aws_instance" "instance-1" {
  ami               = "ami-0a91cd140a1fc148a"
  instance_type     = "t2.micro"
  availability_zone = "us-east-2a"
  key_name          = "main-key"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.test.id
   }

  user_data = <<-EOF
                 #!/bin/bash
                 sudo apt update -y
                 sudo apt install apache2 -y
                 sudo systemctl start apache2
                 sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                 EOF
  tags = {
    Name = "web-server"
  }
}





