output "url" {
  description = "app endpoint"
  value       = "http://${kubernetes_ingress_v1.rabbitmq.status[0].load_balancer.0.ingress.0.hostname}"
}
