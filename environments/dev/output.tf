output "public_ip" {
  value = module.compute.ec2_public_ip
}

output "argocd_url" {
  value = "http://${module.compute.ec2_public_ip}:30080"
}
