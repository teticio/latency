resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
}

locals {
  username = "user"
  password = "password"
}

resource "helm_release" "rabbitmq" {
  name       = "rabbitmq"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "rabbitmq"
  timeout    = 600

  set {
    name  = "replicaCount"
    value = "3"
  }

  set {
    name  = "auth.username"
    value = local.username
  }

  set {
    name  = "auth.password"
    value = local.password
  }

  set {
    name  = "auth.securePassword"
    value = "false"
  }

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "metrics.enabled"
    value = "true"
  }

  set {
    name  = "metrics.serviceMonitor.enabled"
    value = "true"
  }

  set {
    # https://stackoverflow.com/questions/60407082/rabbit-mq-error-while-waiting-for-mnesia-tables
    name  = "clustering.forceBoot"
    value = "true"
  }

  set {
    name  = "podLabels.app"
    value = "calc"
  }

  depends_on = [helm_release.prometheus-operator]
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  timeout    = 600
}

resource "helm_release" "prometheus-operator" {
  name       = "prometheus-operator-crds"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-operator-crds"

  depends_on = [
    helm_release.prometheus
  ]
}

resource "helm_release" "prometheus-adapter" {
  name       = "prometheus-adapter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-adapter"

  set {
    name  = "prometheus.url"
    value = "http://prometheus-server.default"
  }

  set {
    name  = "prometheus.port"
    value = 80
  }

  depends_on = [
    helm_release.prometheus
  ]
}
