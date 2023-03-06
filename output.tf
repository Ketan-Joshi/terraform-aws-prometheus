output "private_ip" {
  value = aws_instance.prometheus.private_ip
}
output "pem_file" {
  value = tls_private_key.ssh_private_key.private_key_pem
}