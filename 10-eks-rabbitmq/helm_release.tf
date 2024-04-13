provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}

resource "helm_release" "alb_ingress_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
}

resource "random_string" "rabbitmq_erlang_cookie" {
  length  = 16
  special = false
  upper   = false
  numeric = false
}

resource "helm_release" "rabbitmq" {
  name       = "rabbitmq"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "rabbitmq"
  timeout    = 1800

  set {
    name  = "replicaCount"
    value = "3"
  }

  set {
    name  = "rabbitmq.username"
    value = "user"
  }

  set {
    name  = "rabbitmq.password"
    value = "password"
  }

  set {
    name  = "rabbitmq.erlangCookie"
    value = random_string.rabbitmq_erlang_cookie.result
  }
}
