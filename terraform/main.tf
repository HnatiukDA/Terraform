terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }


  required_version = ">= 1.2.0"
}

provider "aws" {
  region                   = "us-west-2"
  shared_config_files      = ["C:\\Users\\gnaty\\.aws\\config"]
  shared_credentials_files = ["C:\\Users\\gnaty\\.aws\\credentials"]
}

# Creating EC2 Instances:
resource "aws_key_pair" "laptop" {
  key_name   = "laptop-key"
  public_key = file(var.ssh_public_key)
}

resource "aws_instance" "instance" {
  count           = length(aws_subnet.public_subnet.*.id)
  ami             = data.aws_ami.ubuntu.id
  instance_type   = var.instance_type
  subnet_id       = element(aws_subnet.public_subnet.*.id, count.index)
  security_groups = [aws_security_group.sg.id, ]
  key_name        = "laptop-key"


  tags = {
    "Name"        = "webServer-${count.index}"
    "Environment" = "Test"
    "CreatedBy"   = "Terraform"
  }

  timeouts {
    create = "10m"
  }

  # user_data = file("./userdata.sh")
  user_data = <<-EOL
#!/bin/bash -xe

sudo su
apt update -y
apt install nginx-light -y
systemctl start nginx
systemctl enable nginx
echo 'Welcome to Instance ${count.index}' >> /var/www/html/index.html
EOL

}


# Creating 2 Elastic IPs:
resource "aws_eip" "eip" {
  count            = length(aws_instance.instance.*.id)
  instance         = element(aws_instance.instance.*.id, count.index)
  public_ipv4_pool = "amazon"
  vpc              = true

  tags = {
    "Name" = "EIP-${count.index}"
  }
}

# Creating EIP association with EC2 Instances:
resource "aws_eip_association" "eip_association" {
  count         = length(aws_eip.eip)
  instance_id   = element(aws_instance.instance.*.id, count.index)
  allocation_id = element(aws_eip.eip.*.id, count.index)
}


locals {
  ingress_rules = [{
    name        = "HTTPS"
    port        = 443
    description = "Ingress rules for port 443"
    },
    {
      name        = "HTTP"
      port        = 80
      description = "Ingress rules for port 80"
    },
    {
      name        = "SSH"
      port        = 22
      description = "Ingress rules for port 22"
  }]

}

resource "aws_security_group" "sg" {

  name        = "CustomSG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.custom_vpc.id
  egress = [
    {
      description      = "for all outgoing traffics"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  dynamic "ingress" {
    for_each = local.ingress_rules

    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  tags = {
    Name = "AWS security group dynamic block"
  }

}


#############################################
#Creating Virtual Private Cloud:
#############################################
resource "aws_vpc" "custom_vpc" {
  cidr_block           = var.custom_vpc
  instance_tenancy     = var.instance_tenancy
  enable_dns_support   = true
  enable_dns_hostnames = true
}

#############################################
# Creating Public subnet:
#############################################
resource "aws_subnet" "public_subnet" {
  count             = 2
  vpc_id            = aws_vpc.custom_vpc.id
  availability_zone = data.aws_availability_zones.azs.names[count.index]
  cidr_block        = element(cidrsubnets(var.custom_vpc, 8, 4, 4), count.index)

  tags = {
    "Name" = "Public-Subnet-${count.index}"
  }
}

#############################################
# Creating Internet Gateway:
#############################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    "Name" = "Internet-Gateway"
  }
}

#############################################
# Creating Public Route Table:
#############################################
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    "Name" = "Public-RouteTable"
  }
}

#############################################
# Creating Public Route:
#############################################
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

#############################################
# Creating Public Route Table Association:
#############################################
resource "aws_route_table_association" "public_rt_association" {
  count          = length(aws_subnet.public_subnet) == 2 ? 2 : 0
  route_table_id = aws_route_table.public_rt.id
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
}
