dependency "eks" {
  config_path = "../eks"
}

inputs = {
  cluster_name = dependency.eks.outputs.cluster_name
}
