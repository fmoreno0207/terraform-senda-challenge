variable "vpc_cidr" {
  description = "CIDR block for the VPC"
}
variable "region" {}
variable "vpc_name" {}
variable "subnet_public_name" {}
variable "subnet_puvate_name" {}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
}

variable "vpc_id" {
  description = "ID of the VPC"
}

