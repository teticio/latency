resource "aws_security_group" "app" {
  name = "app"

  ingress {
    description = "app"
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
    Name = "app"
  }
}

resource "aws_instance" "ec2" {
  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.app.id]

  tags = {
    Name = "${var.tag}"
  }

  root_block_device {
    volume_type = "gp2"
    volume_size = var.volume_size
  }

  key_name = var.key_name

  connection {
    user        = "ubuntu"
    private_key = file("${var.key_path}")
    host        = aws_instance.ec2.public_ip
  }

  provisioner "file" {
    source      = "${path.module}/src"
    destination = "~/src"
  }

  provisioner "file" {
    source      = "${path.root}/common"
    destination = "~/common"
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "cd src",
      "chmod +x bootstrap.sh",
      "./bootstrap.sh"
    ]
  }
}
