provider "aws" {
  region                  = "ap-south-1"
  profile                 = "vaishnavi"
}
resource "tls_private_key" "this" {
  algorithm = "RSA"
}
module "key_pair" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name   = "webserver"
  public_key = tls_private_key.this.public_key_openssh
}

resource "aws_vpc" "task4" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "task4"
  }
}

resource "aws_subnet" "task4subnet1a" {
  depends_on = [ aws_vpc.task4 ]
  vpc_id     = aws_vpc.task4.id
  availability_zone = "ap-south-1a"
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "task4subnet-1a"
  }
}

resource "aws_subnet" "task4subnet1b" {
  depends_on = [ aws_vpc.task4 ]
  vpc_id     = aws_vpc.task4.id
  availability_zone = "ap-south-1b"
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "task4subnet-1b"
  }
}

resource "aws_internet_gateway" "task4igw" {
  depends_on = [ aws_vpc.task4 ]
  vpc_id = aws_vpc.task4.id

  tags = {
    Name = "task4-igw"
  }
}

resource "aws_route_table" "task4routetableigw" {
  depends_on = [ aws_internet_gateway.task4igw ]
  vpc_id = aws_vpc.task4.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.task4igw.id
  }

  tags = {
    Name = "task4routetable-igw"
  }
}

resource "aws_route_table_association" "task4routetablesubnet1a" {
  depends_on = [ aws_route_table.task4routetableigw ]
  subnet_id      = aws_subnet.task4subnet1a.id
  route_table_id = aws_route_table.task4routetableigw.id
}

resource "aws_eip" "task4eip" {
  depends_on = [ aws_internet_gateway.task4igw ]
  vpc      = true
  tags = {
      Name = "Task4 EIP"
  }
}


resource "aws_nat_gateway" "task4natgw" {
  depends_on = [ aws_eip.task4eip ]
  allocation_id = aws_eip.task4eip.id
  subnet_id     = aws_subnet.task4subnet1a.id

  tags = {
    Name = "task4-natgw"
  }
}

resource "aws_route_table" "task4routetablenatgw" {
  depends_on = [ aws_nat_gateway.task4natgw ]
  vpc_id = aws_vpc.task4.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.task4natgw.id
  }

  tags = {
    Name = "task4routetable-natgw"
  }
}

resource "aws_route_table_association" "task4routetablesubnet1b" {
  depends_on = [ aws_route_table.task4routetablenatgw ]
  subnet_id      = aws_subnet.task4subnet1b.id
  route_table_id = aws_route_table.task4routetablenatgw.id
}


resource "aws_security_group" "wordpress_security_group" {
  depends_on = [ aws_route_table_association.task4routetablesubnet1a ]
  name = "wordpress_security_group"
  description = "Security group to allow HTTP connection on Wordpress Instance"
  vpc_id = aws_vpc.task4.id
	
  ingress {
	description = "Allow inbound connection on port 80"
	from_port = 80
	to_port = 80
	protocol = "tcp"
	cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
	description = "Allow inbound connection on port 22 for SSH"
	from_port = 22
	to_port = 22
	protocol = "tcp"
	cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
	description = "Allow outbound connections"
	from_port = 0
	to_port = 0
	protocol = "-1"
	cidr_blocks = [ "0.0.0.0/0" ]
  }

  tags = {
	Name = "wordpress_security_group"
  }
}

 resource "aws_instance" "wordpress" {
  depends_on = [ aws_security_group.wordpress_security_group ]
  ami = "ami-2778235d"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.task4subnet1a.id
  key_name = "webserver"
  vpc_security_group_ids = [ aws_security_group.wordpress_security_group.id ]
  tags = {
	Name = "Wordpress"
  }	
} 

resource "aws_security_group" "mysql_security_group" {
  depends_on = [ aws_security_group.wordpress_security_group ]
  name = "mysql_security_group"
  description = "Security group to allow connection from Wordpress Instance on port 3306"
  vpc_id = aws_vpc.task4.id
	
  ingress {
	description = "Allow inbound connection on port 3306"
	from_port = 3306
	to_port = 3306
	protocol = "tcp"
	security_groups = [ aws_security_group.wordpress_security_group.id ]
  }

  ingress {
	description = "Allow inbound connection on port 22 for SSH"
	from_port = 22
	to_port = 22
	protocol = "tcp"
	cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
	description = "Allow outbound connections"
	from_port = 0
	to_port = 0
	protocol = "-1"
	cidr_blocks = [ "0.0.0.0/0" ]
  }

  tags = {
	Name = "mysql_security_group"
  }
}
resource "aws_instance" "mysql" {
  depends_on = [ aws_security_group.mysql_security_group ]
  ami = "ami-49fa8e5f"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.task4subnet1b.id
  key_name = "webserver"
  vpc_security_group_ids = [ aws_security_group.mysql_security_group.id ]
  tags = {
	Name = "MySQL"
  }
}	 