provider "aws" {
  region = var.region # Cambia esto según tu región preferida
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "us-east-1a" # Cambia esto según tu zona preferida
  map_public_ip_on_launch = true

  tags = {
    Name = var.subnet_public_name
  }
}

# resource "aws_subnet" "public_b" {
#   vpc_id                  = aws_vpc.main.id
#   cidr_block              = var.public_subnet_cidr
#   availability_zone       = "us-east-1b" # Cambia esto según tu zona preferida
#   map_public_ip_on_launch = true

#   tags = {
#     Name = var.subnet_public_name_b
#   }
# }

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr
  #availability_zone       = "us-east-1b" # Cambia esto según tu zona preferida

  tags = {
    Name = var.subnet_puvate_name
  }
}

#Crea un GW para salida a internet y asocia la vpc
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

#Crea una tabla de ruteo + la ruta por defecto
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

#asocia la tabla de ruteo con la subnet public
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}


