dependency "eks" {
  config_path = "../eks"
}

dependency "k8s-i" {
  config_path = "../k8s-i"
}

inputs = {
  cluster_name      = dependency.eks.outputs.cluster_name
  rabbitmq_username = dependency.k8s-i.outputs.rabbitmq_username
}
