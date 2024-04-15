provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}

data "aws_eks_cluster_auth" "main" {
  name = module.eks.cluster_name
}

# provider "kubectl" {
#   host                   = module.eks.cluster_endpoint
#   cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
#   token                  = data.aws_eks_cluster_auth.main.token
#   load_config_file       = false
# }

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
            value = local.username
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

resource "kubernetes_manifest" "rabbitmq" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = "rabbitmq-service-monitor"
      namespace = "default"

      labels = {
        team = "backend"
      }
    }

    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "rabbitmq"
        }
      }

      endpoints = [{
        port     = "metrics"
        interval = "5s"
        path     = "/metrics"
      }]
    }
  }

  depends_on = [
    helm_release.rabbitmq
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
    kubernetes_deployment.calc,
    helm_release.rabbitmq
  ]
}

resource "kubernetes_config_map" "prometheus_adapter_config" {
  metadata {
    name = "prometheus-adapter-config"
  }

  data = {
    "config.yaml" = <<-EOL
      rules:
        - seriesQuery: 'rabbitmq_queue_messages_ready{job="kubernetes-pods"}'
          resources:
            overrides:
              kubernetes_namespace: {resource: "namespace"}
              kubernetes_pod_name: {resource: "pod"}
          name:
            as: "rabbitmq_queue_messages_ready"
          metricsQuery: 'sum(rate(rabbitmq_queue_messages_ready{job="kubernetes-pods"}[5m])) by (namespace)'
    EOL
  }

  depends_on = [
    helm_release.prometheus-adapter
  ]
}
