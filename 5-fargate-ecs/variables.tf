variable "tag" {
  type    = string
  default = "fargate-ecs"
}

variable "hosted_zone" {
  type    = string
  default = "teticio.co.uk"
}

variable "domain" {
  type    = string
  default = "latency.teticio.co.uk"
}
