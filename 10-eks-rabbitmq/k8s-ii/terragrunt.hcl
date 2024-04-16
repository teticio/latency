dependency "eks" {
  config_path = "../eks"
}

dependency "k8s-i" {
  config_path = "../k8s-i"
}

inputs = {
  cluster_endpoint       = dependency.eks.outputs.cluster_endpoint
  cluster_ca_certificate = dependency.eks.outputs.cluster_certificate_authority_data
  cluster_token          = dependency.eks.outputs.cluster_token
  cluster_name           = dependency.eks.outputs.cluster_name
  rabbitmq_username      = dependency.k8s-i.outputs.rabbitmq_username
}
