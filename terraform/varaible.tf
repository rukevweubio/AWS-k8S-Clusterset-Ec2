variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability Zone for the subnet"
  default     = "us-east-1a"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  default  = "ami-020cba7c55df1f615"

}

variable "master_instance_type" {
  default = "t3.medium"
}

variable "worker_instance_type" {
  default = "t3.medium"
}

variable "my_ip_cidr" {
  description = "Your IP address with /32 CIDR for SSH access"
  default     = "0.0.0.0/0"
}

variable "aws_key_pair"{
  description= "the diretory of teh key"
  default= "id_rsa.pub.pem"
}