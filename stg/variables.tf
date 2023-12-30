#variables
variable "region" {
  
}

variable "cidr" {
  type = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type = list(string)
  default = [   "us-east-1a", 
                "us-east-1b", 
                "us-east-1c"    ]
}

variable "subnets-ips" {
  type = list(string)
  default = [   "10.0.1.0/24",
                "10.0.3.0/24",
                "10.0.5.0/24"  ]
}

variable "project" {
  description = "Nombre del proyecto"
  type = string
}


variable "environment_name" {
  description = "Environment"
  type        = string
}

