terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }

    docker = {
      source = "kreuzwerker/docker"
    }

    # kubectl = {
    #   source  = "gavinbunney/kubectl"
    # }
  }
}
