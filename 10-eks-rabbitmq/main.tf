data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_ec2_tag" "elb_tag" {
  count       = length(data.aws_subnets.default.ids)
  resource_id = data.aws_subnets.default.ids[count.index]
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "internal_elb_tag" {
  count       = length(data.aws_subnets.default.ids)
  resource_id = data.aws_subnets.default.ids[count.index]
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

data "local_file" "policy" {
  # from https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/install/iam_policy.json
  filename = "${path.module}/policy.aws-loadbalancer-controller.json"
}

resource "aws_iam_policy" "loadbalancer_controller_policy" {
  name   = "latency-loadbalancer-controller-policy"
  policy = data.local_file.policy.content
}

module "eks" {
  source                                   = "terraform-aws-modules/eks/aws"
  cluster_name                             = "latency"
  cluster_version                          = "1.29"
  cluster_endpoint_public_access           = true
  vpc_id                                   = data.aws_vpc.default.id
  subnet_ids                               = data.aws_subnets.default.ids
  control_plane_subnet_ids                 = data.aws_subnets.default.ids
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    node_group = {
      min_size       = 1
      max_size       = 3
      desired_size   = 1
      instance_types = ["t3.large"]
      capacity_type  = "SPOT"

      iam_role_additional_policies = {
        ebs_csi_driver_policy           = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        load_balancer_controller_policy = aws_iam_policy.loadbalancer_controller_policy.arn
      }
    }
  }

  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  tags = {
    Name = var.tag
  }
}
