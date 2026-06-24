output "server_public_ip" {
  description = "Elastic IP of the control plane."
  value       = aws_eip.server.public_ip
}

output "server_private_ip" {
  value = aws_instance.server.private_ip
}

output "workers" {
  description = "List of worker nodes with their names and IPs (consumed by the inventory template)."
  value = [for w in aws_instance.worker : {
    name       = w.tags["Name"]
    public_ip  = w.public_ip
    private_ip = w.private_ip
  }]
}
