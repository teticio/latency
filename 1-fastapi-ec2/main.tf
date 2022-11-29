resource "tls_private_key" "this" {
  algorithm = "RSA"
}

module "key_pair" {
  source     = "terraform-aws-modules/key-pair/aws"
  key_name   = "latency"
  public_key = tls_private_key.this.public_key_openssh

  tags = {
    Name = var.tag
  }
}

resource "aws_security_group" "latency" {
  name = "latency"

  ingress {
    description = "API"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.tag
  }
}

resource "aws_instance" "ec2" {
  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.latency.id]
  key_name               = "latency"

  root_block_device {
    volume_type = "gp2"
    volume_size = var.volume_size
  }

  connection {
    user        = "ubuntu"
    private_key = tls_private_key.this.private_key_pem
    host        = aws_instance.ec2.public_ip
  }

  provisioner "file" {
    source      = "${path.module}/src"
    destination = "/tmp/src"
  }

  provisioner "file" {
    source      = "${path.root}/common"
    destination = "/tmp/common"
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "cd /tmp/src",
      "chmod +x bootstrap.sh",
      "./bootstrap.sh"
    ]
  }

  tags = {
    Name = var.tag
  }
}
