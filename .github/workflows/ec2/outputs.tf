output "instance_id" {
  description = "The ID of the Windows EC2 instance"
  value       = aws_instance.windows_server.id
}

output "vpc_id" {
  description = "The ID of the custom VPC"
  value       = aws_vpc.main.id
}
