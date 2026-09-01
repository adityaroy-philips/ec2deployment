resource "aws_instance" "private_ec2" {
  ami           = "ami-xxxxxxxx" # Amazon Linux 2
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private.id
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  tags = { Name = "private-ec2" }
}
