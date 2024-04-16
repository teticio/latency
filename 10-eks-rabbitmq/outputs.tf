output "url" {
  description = "RabbitMQ endpoint with credentials"
  sensitive   = true
  value       = var.url
}
