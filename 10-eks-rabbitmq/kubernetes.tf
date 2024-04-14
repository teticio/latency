# aws eks update-kubeconfig --name latency
# echo $(kubectl get secret --namespace default rabbitmq -o jsonpath="{.data.rabbitmq-password}" | base64 --decode)
# kubectl get ingress rabbitmq-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}
data "kubernetes_service" "rabbitmq" {
  metadata {
    name = "rabbitmq"
  }

  depends_on = [
    helm_release.rabbitmq
  ]
}

data "kubernetes_secret" "rabbitmq" {
  metadata {
    name = "rabbitmq"
  }

  depends_on = [
    helm_release.rabbitmq
  ]
}