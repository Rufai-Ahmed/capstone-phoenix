output "server_public_ip" {
  description = "Control-plane public IP (Elastic IP). SSH + ingress DNS target."
  value       = module.compute.server_public_ip
}

output "server_private_ip" {
  description = "Control-plane private IP. k3s agents join against this."
  value       = module.compute.server_private_ip
}

output "worker_public_ips" {
  description = "Worker public IPs (for SSH)."
  value       = [for w in module.compute.workers : w.public_ip]
}

output "dns_target" {
  description = "Point your domain's A record(s) (e.g. taskapp.<domain>) at this IP."
  value       = module.compute.server_public_ip
}

output "ssh_server" {
  description = "Ready-to-paste SSH command for the control plane."
  value       = "ssh ubuntu@${module.compute.server_public_ip}"
}
