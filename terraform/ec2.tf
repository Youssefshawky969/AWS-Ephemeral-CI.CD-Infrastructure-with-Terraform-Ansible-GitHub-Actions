resource "aws_instance" "web" {
  ami = var.ami_id
  instance_type = var.instance_type
  key_name = aws_key_pair.ci_key.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "ci_ephemeral_web"

  associate_public_ip_address = true  
  }

}



