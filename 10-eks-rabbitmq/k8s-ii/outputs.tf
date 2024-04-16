output "url" {
  description = "RabbitMQ endpoint with credentials"
  sensitive   = true

  value = format(
    "amqp://%s:%s@%s",
    var.rabbitmq_username,
    data.kubernetes_secret.rabbitmq.data["rabbitmq-password"],
    data.kubernetes_service.rabbitmq.status.0.load_balancer.0.ingress.0.hostname
  )
}
