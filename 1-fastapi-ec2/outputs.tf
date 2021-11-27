output "url" {
  description = "app endpoint"
  value       = "http://${aws_instance.ec2.public_ip}:8000/"
}
