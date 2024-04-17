data "aws_caller_identity" "this" {}

provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

data "aws_iam_openid_connect_provider" "oidc" {
  url = data.aws_eks_cluster.this.identity.0.oidc.0.issuer
}

module "eks_blueprints_addons" {
  source            = "aws-ia/eks-blueprints-addons/aws"
  cluster_name      = var.cluster_name
  cluster_endpoint  = data.aws_eks_cluster.this.endpoint
  cluster_version   = data.aws_eks_cluster.this.version
  oidc_provider_arn = data.aws_iam_openid_connect_provider.oidc.arn
  enable_karpenter  = true

  karpenter = {
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
  }

  karpenter_enable_spot_termination          = true
  karpenter_enable_instance_profile_creation = true
  karpenter_node = {
    iam_role_use_name_prefix = false
  }
}

module "aws-auth" {
  source                    = "terraform-aws-modules/eks/aws//modules/aws-auth"
  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = module.eks_blueprints_addons.karpenter.node_iam_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    },
  ]
}

resource "kubernetes_manifest" "karpenter_default_ec2_node_class" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1beta1"
    kind       = "EC2NodeClass"

    metadata = {
      name = "default"
    }

    spec = {
      role      = "${module.eks_blueprints_addons.karpenter.node_iam_role_name}"
      amiFamily = "AL2"

      securityGroupSelectorTerms = [{
        tags = {
          "karpenter.sh/discovery" = "latency"
        }
      }]

      subnetSelectorTerms = [{
        tags = {
          "karpenter.sh/discovery" = "latency"
        }
      }]

      tags = {
        KarpenterNodePoolName    = "default"
        NodeType                 = "default"
        "karpenter.sh/discovery" = "latency"
      }
    }
  }

  depends_on = [
    module.eks_blueprints_addons.karpenter
  ]
}
resource "kubernetes_manifest" "karpenter_default_node_pool" {
  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"

    metadata = {
      name = "default"
    }

    spec = {
      template = {
        spec = {

          nodeClassRef = {
            name = "default"
          }

          requirements = [
            {
              key      = "karpenter.k8s.aws/instance-family"
              operator = "In"
              values   = ["t3"]
            },
            {
              key      = "karpenter.k8s.aws/instance-size"
              operator = "In"
              values   = ["large"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot"]
            }
          ]
        }
      }

      disruption = {
        consolidationPolicy = "WhenUnderutilized"
      }
    }
  }

  depends_on = [
    kubernetes_manifest.karpenter_default_ec2_node_class
  ]
}
