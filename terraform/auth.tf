resource "aws_key_pair" "ci_key" {
  key_name = "server_key"
  public_key = file("key.pem.pub")
}