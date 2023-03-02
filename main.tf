resource "tls_private_key" "ssh_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh_key" {
  key_name   = var.key_name
  public_key = tls_private_key.ssh_private_key.public_key_openssh
  provisioner "local-exec" { # This will create "prometheus.pem" where the terraform will run!!
    command = "rm -f ./prometheus.pem && echo '${tls_private_key.ssh_private_key.private_key_pem}' > ./prometheus.pem && chmod 400 prometheus.pem"
  }
}

data "template_file" "userdata" {
  template = file("${path.module}/prometheus_userdata.sh")
  vars = {
    kubernetes_cluster_endpoint     = var.kubernetes_cluster_endpoint
    kubernetes_cluster_token        = var.kubernetes_cluster_token
  }
}

resource "aws_instance" "prometheus" {
  ami = "ami-0b5eea76982371e91"
  instance_type = var.instance_type_prometheus 
  key_name = var.key_name
  subnet_id = var.subnet_id
  disable_api_termination = true
  vpc_security_group_ids = [aws_security_group.prometheus_sg.id]
  # associate_public_ip_address = true
  ebs_block_device {
    device_name = "/dev/xvda"
    volume_size = var.volume_size_prometheus
  }
  user_data = data.template_file.userdata.rendered
  depends_on = [
    aws_key_pair.ssh_key
  ]
  tags = {
    Name = "nw-social-monitoring-${var.environment}"
  }
}

resource "aws_security_group" "prometheus_sg" {
  name = "nw-social-monitoring-${var.environment}-sg"
  vpc_id =  var.vpc_id
  ingress {
    description = "ingress rules"
    cidr_blocks = [var.cidr_block]
    from_port = 22
    protocol = "tcp"
    to_port = 22
  }
  ingress {
    description = "ingress rules"
    cidr_blocks = [var.cidr_block]
    from_port = 9090
    protocol = "tcp"
    to_port = 9090
  }
  egress {
    description = "egress rules"
    cidr_blocks = [ "0.0.0.0/0" ]
    from_port = 0
    protocol = "-1"
    to_port = 0
  }
  tags = {
    Name = "nw-social-monitoring-${var.environment}-sg"
  }
}