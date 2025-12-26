variable "region" {
  description = "AWS region"
}

variable "access_key" {
  description = "The AWS access key to deploy resources"
  
}

variable "secret_key" {
  description = "The AWS secret key to deploy resources"
  
}

variable "key_name" {
  type = string
}

variable "public_key" {
  type = string
}



variable "instance_type" {
  default = "t3.micro"
}



variable "ami_id" {
  description = "The AMI ID for the NGINX server"
  default     = "ami-068c0051b15cdb816" 
}  







