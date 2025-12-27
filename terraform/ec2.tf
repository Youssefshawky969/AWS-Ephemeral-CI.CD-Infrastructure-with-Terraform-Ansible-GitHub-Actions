resource "aws_instance" "web" {
  ami = var.ami_id
  instance_type = var.instance_type
  iam_instance_profile    = ec2-ssm-role

  tags = {
    Name = "ci_ephemeral_web"

  associate_public_ip_address = true  
  }

}







