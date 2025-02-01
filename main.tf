provider "aws" {
  region = "us-east-2"
}

resource "aws_vpc" "main" {
  cidr_block = "192.168.0.0/24"
  
  tags = {
    Name = "terraform-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-gw"
  }
}
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "terraform-rt"
  }
}
resource "aws_subnet" "subnet" {
      vpc_id    = aws_vpc.main.id
  cidr_block = "192.168.0.0/28"
  availability_zone = "us-east-2a"
  tags = {
    Name = "terraform-subnet"
  }
}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.rt.id
}
resource "aws_security_group" "sg" {
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

  ingress {
    from_port   = 443
    to_port     = 443
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
    Name = "terraform-sg"
  }
}
resource "aws_network_interface" "eni" {
  subnet_id       = aws_subnet.subnet.id
  private_ips     = ["192.168.0.12"]
  security_groups = [aws_security_group.sg.id]

  tags = {
    Name = "terraform-eni"
  }
}
resource "aws_eip" "eip" {
  vpc               = true
  network_interface = aws_network_interface.eni.id

  tags = {
    Name = "terraform-eip"
  }
}
resource "aws_instance" "web" {
  ami           = "ami-036841078a4b68e14" 
  instance_type = "t2.micro"
  network_interface {
    network_interface_id = aws_network_interface.eni.id
    device_index         = 0
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y apache2
              sudo systemctl start apache2
              sudo systemctl enable apache2
              EOF

  tags = {
    Name = "terraform-server"
  }
}

output "instance_public_ip" {
  value = aws_instance.web.public_ip
}
resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-task-bucket"
  acl    = "private"

}

resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = "terraform-task-dynamodb"
  hash_key     = "LockID"
  read_capacity  = 20
  write_capacity = 20

  attribute {
    name = "LockID"
    type = "S"
  }
}

terraform {
  backend "s3" {
    bucket         = "terraform-task-bucket"
    key            = "terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-task-dynamodb"
    encrypt        = true
  }
}
