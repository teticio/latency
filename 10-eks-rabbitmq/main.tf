data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
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
    }
  }

  tags = {
    Name = var.tag
  }
}
