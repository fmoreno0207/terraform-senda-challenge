output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

# output "security_group_web_id" {
#   value = aws_security_group.web_sg.id
  
# }
