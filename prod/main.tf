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
#CloudWatch
resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "${var.project}-${var.environment_name}-CPUUtilizationAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "${var.project}-${var.environment_name}-CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 10
  alarm_description   = "Scale up when CPU usage is greater than or equal to 80% for 2 consecutive periods."

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_actions = [aws_autoscaling_policy.asg-policy.arn]
}

#########################################################
# vpc from module
module "networking" {
  source               = "../modules/networking" # Ruta al directorio que contiene los archivos del módulo
  region = "us-east-1"
  vpc_name = "VPC-Fer-prod"
  subnet_public_name = "Subnet Publica"
  subnet_puvate_name = "Subnet Privada"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidr   = "10.0.100.0/24"
  private_subnet_cidr  = "10.0.3.0/24"
#  sg_name = "security autoscaling"
#  security_group_name = "acces autosacaling"
  vpc_id = module.networking.vpc_id

}

#########################################################
# S3 from module
module "buckets" {
  source       = "../modules/buckets"
  region       = "us-east-1" # Puedes cambiar esto según tu región preferida
  bucket_name   = "bucket-prod31" # Puedes cambiar esto según el nombre que desees
}

#########################################################
#ec2

module "instances" {
  source    = "../modules/instances" # Ruta al directorio que contiene los archivos del módulo
  vpc_id    = module.networking.vpc_id
  subnet_id = module.networking.public_subnet_id
  ec2_name = "ec2-prod-test"

}

#########################################################
#dynamodb
module "dynamodb_example" {
  source        = "../modules/dynamodb"
  region = "us-east-1"
  table_name    = "prod-tabla-dynamodb"
  read_capacity = 20
  write_capacity = 20
}  