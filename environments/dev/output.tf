output "ec2_public_ip" {
  value = module.compute.ec2_public_ip
}

output "argocd_url" {
  value = module.compute.argocd_url
}
