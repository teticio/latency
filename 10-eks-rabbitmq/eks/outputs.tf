output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  sensitive = true
  value = module.eks.cluster_certificate_authority_data
}

output "cluster_token" {
  sensitive = true
  value     = data.aws_eks_cluster_auth.cluster.token
}

output "cluster_name" {
  value = module.eks.cluster_name
}
