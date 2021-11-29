variable "tag" {
  type    = string
  default = "latency-fastapi-ec2"
}

variable "ami" {
  type    = string
  default = "ami-0194c3e07668a7e36"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "volume_size" {
  type    = string
  default = "8"
}
