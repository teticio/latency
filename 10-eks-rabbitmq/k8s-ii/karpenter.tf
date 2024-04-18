# This cannot even be planned if karpenter is not installed
resource "kubernetes_manifest" "karpenter_default_ec2_node_class" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1beta1"
    kind       = "EC2NodeClass"

    metadata = {
      name = "default"
    }

    spec = {
      role      = var.karpenter_node_iam_role_name
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
