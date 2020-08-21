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
resource "aws_vpc" "task3" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "task3"
  }
}

resource "aws_subnet" "task3subnet1a" {
  depends_on = [ aws_vpc.task3 ]
  vpc_id     = aws_vpc.task3.id
  availability_zone = "ap-south-1a"
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "task3subnet-1a"
  }
}

resource "aws_subnet" "task3subnet1b" {
  depends_on = [ aws_vpc.task3 ]
  vpc_id     = aws_vpc.task3.id
  availability_zone = "ap-south-1b"
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "task3subnet-1b"
  }
}

resource "aws_internet_gateway" "task3igw" {
  depends_on = [ aws_vpc.task3 ]
  vpc_id = aws_vpc.task3.id

  tags = {
    Name = "task3-igw"
  }
}

resource "aws_route_table" "task3routetableigw" {
  depends_on = [ aws_internet_gateway.task3igw ]
  vpc_id = aws_vpc.task3.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.task3igw.id
  }

  tags = {
    Name = "task3routetable-igw"
  }
}

resource "aws_route_table_association" "task3routetablesubnet1a" {
  depends_on = [ aws_route_table.task3routetableigw ]
  subnet_id      = aws_subnet.task3subnet1a.id
  route_table_id = aws_route_table.task3routetableigw.id
}

resource "aws_security_group" "wordpress_security_group" {
  depends_on = [ aws_route_table_association.task3routetablesubnet1a ]
  name = "wordpress_security_group"
  description = "Security group to allow HTTP connection on Wordpress Instance"
  vpc_id = aws_vpc.task3.id
	
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


resource "aws_security_group" "mysql_security_group" {
  depends_on = [ aws_security_group.wordpress_security_group ]
  name = "mysql_security_group"
  description = "Security group to allow connection from Wordpress Instance on port 3306"
  vpc_id = aws_vpc.task3.id
	
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

  tags = {
	Name = "mysql_security_group"
  }
}

 resource "aws_instance" "mysql" {
  depends_on = [ aws_security_group.mysql_security_group ]
  ami = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.task3subnet1b.id
  key_name = "webserver"
  vpc_security_group_ids = [ aws_security_group.mysql_security_group.id ]
  tags = {
	Name = "MySQL"
  }
}	

 resource "aws_instance" "wordpress" {
  depends_on = [ aws_security_group.wordpress_security_group ]
  ami = "ami-2778235d"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.task3subnet1a.id
  key_name = "webserver"
  vpc_security_group_ids = [ aws_security_group.wordpress_security_group.id ]
  tags = {
	Name = "Wordpress"
  }	
} 
resource "null_resource" "launchingec2"  {



	provisioner "local-exec" {
	    command = "start chrome ${aws_instance.wordpress.public_ip}"
  	}
}