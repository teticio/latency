# aws eks update-kubeconfig --name latency
# echo $(kubectl get secret --namespace default rabbitmq -o jsonpath="{.data.rabbitmq-password}" | base64 --decode)
# kubectl get ingress rabbitmq-management-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}

resource "kubernetes_ingress_v1" "rabbitmq_management" {
  metadata {
    name = "rabbitmq-management-ingress"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "rabbitmq"
              port {
                number = 15672
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "rabbitmq" {
  metadata {
    name = "rabbitmq-ingress"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "rabbitmq"
              port {
                number = 5672
              }
            }
          }
        }
      }
    }
  }
}
