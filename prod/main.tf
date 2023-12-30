terraform {
  required_version = ">= 1.1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.31.0"
    }
  }

  backend "s3" {
    bucket         = "senda-prod-tf-state-bucket"          
    dynamodb_table = "senda-prod-tf-state-dynamo-db-table" 
    key            = "terraform.tfstate"
    region         = "us-east-1" 
    encrypt        = true
  }
}



#########################################################
#VPC

resource "aws_vpc" "vpc" {
  cidr_block = var.cidr

  tags = {
    Name = "${var.project}-${var.environment_name}-vpc"
  }
}

resource "aws_subnet" "pub-subnets" {
  count             = "${length(var.azs)}"
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "${element(var.subnets-ips, count.index)}"
  availability_zone = "${element(var.azs, count.index)}"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-${var.environment_name}-public-${element(var.azs, count.index)}"
  }
}

#########################################################
# IGW

resource "aws_internet_gateway" "i-gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.project}-${var.environment_name}-i-gateway"
  }
}

#########################################################
# Route Table

resource "aws_route_table" "pub-table" {
  vpc_id    = "${aws_vpc.vpc.id}"

  tags = {
    name = "${var.project}-${var.environment_name}-route-table-public"
    Terraform   = "true"
    Environment = "${var.environment_name}"
  }
}

resource "aws_route" "pub-route" {
  route_table_id         = "${aws_route_table.pub-table.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.i-gateway.id }"
}

resource "aws_route_table_association" "as-pub" {
  count          = "${length(var.azs)}"
  route_table_id = "${aws_route_table.pub-table.id}"
  subnet_id      = "${aws_subnet.pub-subnets[count.index].id}"  
}

#########################################################
# SG acces ssh

resource "aws_security_group" "sg1" {
  name        = "allow-ssh"
  description = "Port 22"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Allow Port 22"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all ip and ports outboun"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Terraform   = "true"
    Name        = "${var.project}-${var.environment_name}-sg1"
    Environment = "${var.environment_name}"
  }  
}

# SG acces elb
resource "aws_security_group" "sg2" {
  name        = "allow-web"
  description = "Port 80"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description      = "Allow Port 22"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description = "Allow all ip and ports outboun"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Terraform   = "true"
    Name        = "${var.project}-${var.environment_name}-sg2"
    Environment = "${var.environment_name}"
  }
}

#########################################################
# ElB

resource "aws_lb" "alb" {
  name               = "${var.project}-${var.environment_name}-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.sg1.id}", "${aws_security_group.sg2.id}"]
  subnets            = "${aws_subnet.pub-subnets[*].id}"


  tags = {
    Terraform   = "true"
    Environment = "${var.environment_name}"
  }
}

resource "aws_lb_target_group" "tg-group" {
  name     = "${var.project}-${var.environment_name}-tg-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 6
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "lb-listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-group.arn
  }
}

#########################################################
# scaling

resource "aws_launch_template" "template" {
  name                  = "${var.project}-${var.environment_name}-ec2-template"
  image_id               = "ami-0c7217cdde317cfec"
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.sg1.id}", "${aws_security_group.sg2.id}"]
  ebs_optimized          = false #t2.micro doesn;t support
  update_default_version = true
  user_data              = filebase64("http.sh")
  #key_name               = "terraform-key"

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
  
  tags = {
    Name        = "${var.project}-${var.environment_name}-ec2-app"
    Terraform   = "true"
    Environment = "${var.environment_name}"
  }
  }
}


#Auto Scaling Group

resource "aws_autoscaling_group" "asg" {
  name                = "${var.project}-${var.environment_name}-asg"
  max_size            = 3
  min_size            = 1
  desired_capacity    = 2
  vpc_zone_identifier = "${aws_subnet.pub-subnets[*].id}"
  health_check_type   = "EC2"

  launch_template {
    id      = "${aws_launch_template.template.id}"
    version = "${aws_launch_template.template.latest_version}"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 75
    }
    
  }
  

}

resource "aws_autoscaling_attachment" "asg-attach" {
  autoscaling_group_name  = "${aws_autoscaling_group.asg.id}"
  lb_target_group_arn    = "${aws_lb_target_group.tg-group.id}"
}

resource "aws_autoscaling_policy" "asg-policy" {
  name                    = "policy-asg"
  autoscaling_group_name  = "${aws_autoscaling_group.asg.id}"
  policy_type             = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 75.0
    
  }
  
}

#########################################################
# EC2 from module

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  #for_each = toset(["1", "2", "3"])
  #name = "${var.project}-${var.environment_name}-instance-${each.key}"
  
  name = "${var.project}-${var.environment_name}-ec2-from-module${count.index}"
  
  count                  = 1
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ssh-keys.key_name
  monitoring             = true
  vpc_security_group_ids = [aws_security_group.sg1.id]
  subnet_id              = "${aws_subnet.pub-subnets[count.index].id}"

  tags = {
    Terraform   = "true"
    Environment = "${var.environment_name}"
  }
}

resource "aws_key_pair" "ssh-keys" {
  key_name   = "${var.project}-${var.environment_name}-ssh-keys"
  public_key = file("./custom/id_rsa.pub")
}


#########################################################
# S3 from module

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "${var.project}${var.environment_name}-s3"
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = true
  }
}


#########################################################
# vpc from module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.project}-${var.environment_name}-vpc-from-module"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform = "true"
    Environment = "${var.environment_name}"

  }
  
}