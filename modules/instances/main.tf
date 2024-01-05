provider "aws" {
  region = "us-east-1" # Cambia esto según tu región preferida
}

resource "aws_instance" "ec2" {
  ami             = "ami-0c7217cdde317cfec" # ID de la AMI, debes cambiar esto
  instance_type   = "t2.micro" # Tipo de instancia, puedes cambiar esto

  vpc_security_group_ids = [aws_security_group.ec2.id]
  subnet_id              = var.subnet_id
  #key_name               = var.key_name

  tags = {
    Name = var.ec2_name
  }
}

resource "aws_security_group" "ec2" {
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
