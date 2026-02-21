output "ec2_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "argocd_url" {
  value = "http://${aws_instance.app_server.public_ip}:30080"
}
