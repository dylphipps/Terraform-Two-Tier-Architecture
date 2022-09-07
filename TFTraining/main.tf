# Create VPC
resource "aws_vpc" "project" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  instance_tenancy     = "default"
  tags = {
    Name = "Project Vpc"
  }
}

#----------------SUBNETS AND NETWORK CONFIG-------------


# Create Public Subnet 1
resource "aws_subnet" "public_subnet1" {
  vpc_id                  = aws_vpc.project.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "Public Subnet 1"
  }
}

# Create Public Subnet 2
resource "aws_subnet" "public_subnet2" {
  vpc_id                  = aws_vpc.project.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"

  tags = {
    Name = "Public Subnet 2"
  }
}

# Create Private Subnet 1
resource "aws_subnet" "private_subnet1" {
  vpc_id            = aws_vpc.project.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Private Subnet 1"
  }
}

# Create Private Subnet 2
resource "aws_subnet" "private_subnet2" {
  vpc_id            = aws_vpc.project.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Private Subnet 2"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "project_gw" {
  vpc_id = aws_vpc.project.id

  tags = {
    Name = "Project IGW"
  }
}


# Create EIP 
resource "aws_eip" "nat" {
  depends_on = [aws_internet_gateway.project_gw]
  vpc        = true
}

# Create Nat Gateway
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnet1.id

  tags = {
    Name = "Project NAT"
  }
}

#-------------ROUTE TABLES-----------------------

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.project.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.project_gw.id
  }
  tags = {
    Name = "Public"
  }
}

# Associating Pub RT with Pub Subnet 1
resource "aws_route_table_association" "public_route1" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public.id
}

# Associating Pub RT with Pub Subnet 2
resource "aws_route_table_association" "public_route2" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public.id
}


# Private Route Table 
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.project.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }
  tags = {
    Name = "Private"
  }
}

# Associating Priv RT with Priv Subnet 1
resource "aws_route_table_association" "private_route1" {
  subnet_id      = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.private.id
}

# Associating Priv RT with Priv Subnet 2
resource "aws_route_table_association" "private_route2" {
  subnet_id      = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.private.id
}


#--------------INSTANCES-----------------------


# Create Bastion Host 
resource "aws_instance" "bastion" {
  ami                         = "ami-090fa75af13c156b4"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  subnet_id                   = aws_subnet.public_subnet1.id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.key_pair.key_name

  tags = {
    Name = "Bastion"
  }
}
# Create Webserver Instance
resource "aws_instance" "webserver" {
  ami                         = "ami-090fa75af13c156b4"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.webserver_sg.id]
  subnet_id                   = aws_subnet.public_subnet2.id
  associate_public_ip_address = true
  user_data                   = file("./userdata.tpl")
  key_name                    = aws_key_pair.key_pair.key_name

  tags = {
    Name = "Webserver"
  }
}


# Keypair for SSH
resource "aws_key_pair" "key_pair" {
  key_name   = "tfkey"
  public_key = file("~/.ssh/tfkey.pub")
}


#--------------SECURITY GROUPS---------------------


# Webserver Security Groups
resource "aws_security_group" "webserver_sg" {
  name        = "HTTP_Access"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.project.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Webserver SG"
  }
}

# Bastion Security Group
resource "aws_security_group" "bastion_sg" {
  name        = "ssh_only_bastion"
  description = "traffic via Bastion only"
  vpc_id      = aws_vpc.project.id

  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "Bastion SG"
  }
}

# RDS Security Group
resource "aws_security_group" "private_database_sg" {
  name        = "MYSQL_Access"
  description = "Allow MYSQL inbound traffic"
  vpc_id      = aws_vpc.project.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.webserver_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Private DB SG"
  }
}


#--------------DATABASE AND SUBNET------------------


# RDS Database 
resource "aws_db_instance" "DB" {
  allocated_storage      = 8
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  db_name                = "mydb"
  db_subnet_group_name   = aws_db_subnet_group.project.name
  username               = "foo"
  password               = "foobarbaz"
  parameter_group_name   = "default.mysql5.7"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.private_database_sg.id]
}

# RDS Subnet 
resource "aws_db_subnet_group" "project" {
  name       = "project"
  subnet_ids = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id]

  tags = {
    Name = "DB subnet"
  }
}