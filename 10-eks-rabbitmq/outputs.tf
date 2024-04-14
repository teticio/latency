output "url" {
  description = "RabbitMQ endpoint with credentials"
  sensitive   = true

  value = format(
    "amqp://%s:%s@%s",
    [for s in helm_release.rabbitmq.set : s.value if s.name == "rabbitmq.username"][0],
    data.kubernetes_secret.rabbitmq.data["rabbitmq-password"],
    data.kubernetes_service.rabbitmq.status.0.load_balancer.0.ingress.0.hostname
  )
}
