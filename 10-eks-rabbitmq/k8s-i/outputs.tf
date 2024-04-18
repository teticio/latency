output "rabbitmq_username" {
  value = local.username
}

output "karpenter_node_iam_role_name" {
  value = module.eks_blueprints_addons.karpenter.node_iam_role_name
}
