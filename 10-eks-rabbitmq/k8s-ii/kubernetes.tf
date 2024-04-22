data "kubernetes_service" "rabbitmq" {
  metadata {
    name = "rabbitmq"
  }
}

data "kubernetes_secret" "rabbitmq" {
  metadata {
    name = "rabbitmq"
  }
}

resource "kubernetes_deployment" "calc" {
  metadata {
    name = "calc"
    labels = {
      app = "calc"
    }
  }

  spec {
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

          resources {
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }

            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          env {
            name  = "RABBITMQ_USERNAME"
            value = var.rabbitmq_username
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

resource "kubernetes_horizontal_pod_autoscaler_v2" "calc" {
  metadata {
    name = "calc-hpa"
  }

  spec {
    max_replicas = 10
    min_replicas = 1

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "calc"
    }

    metric {
      type = "Pods"

      pods {
        metric {
          name = "rabbitmq_queue_messages_ready"
        }

        target {
          type          = "AverageValue"
          average_value = 10
        }
      }
    }
  }

  depends_on = [
    kubernetes_deployment.calc
  ]
}
