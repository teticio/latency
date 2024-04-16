dependency "eks" {
  config_path = "../eks"
}

inputs = {
  cluster_endpoint       = dependency.eks.outputs.cluster_endpoint
  cluster_ca_certificate = dependency.eks.outputs.cluster_certificate_authority_data
  cluster_token          = dependency.eks.outputs.cluster_token
  cluster_name           = dependency.eks.outputs.cluster_name
}
