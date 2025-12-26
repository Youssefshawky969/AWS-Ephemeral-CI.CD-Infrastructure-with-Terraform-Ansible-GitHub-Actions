variable "region" {
  description = "AWS region"
}

variable "key_name" {
  description = "EC2 key pair name"
}


variable "instance_type" {
  default = "t3.micro"
}



variable "ami_id" {
  description = "The AMI ID for the NGINX server"
  default     = "ami-068c0051b15cdb816" 
}  





