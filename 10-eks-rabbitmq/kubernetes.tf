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

resource "kubernetes_deployment" "calc" {
  metadata {
    name = "calc"
    labels = {
      app = "calc"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "calc"
      }
    }

    template {
      metadata {
        labels = {
          app = "calc"
        }
      }

      spec {
        container {
          image = module.ecr.image_uri
          name  = "latency-calc"

          env {
            name  = "RABBITMQ_USERNAME"
            value = [for s in helm_release.rabbitmq.set : s.value if s.name == "rabbitmq.username"][0]
          }

          env {
            name = "RABBITMQ_PASSWORD"

            value_from {
              secret_key_ref {
                name = data.kubernetes_secret.rabbitmq.metadata[0].name
                key  = "rabbitmq-password"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    module.ecr
  ]
}

resource "kubernetes_horizontal_pod_autoscaler" "calc" {
  metadata {
    name      = "calc-hpa"
    namespace = "default"
  }

  spec {
    max_replicas = 10
    min_replicas = 2
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "calc"
    }

    target_cpu_utilization_percentage = 80
  }

  depends_on = [
    kubernetes_deployment.calc
  ]
}
