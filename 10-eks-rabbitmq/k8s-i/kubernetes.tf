resource "kubernetes_annotations" "rabbitmq" {
  api_version = "v1"
  kind        = "Service"

  metadata {
    name = "rabbitmq"
  }

  annotations = {
    "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
    "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
    "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
  }

  depends_on = [helm_release.rabbitmq]
}
