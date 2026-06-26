data "aws_availability_zones" "available" {
  state = "available"
}

module "network" {
  source              = "./modules/network"
  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  availability_zones  = slice(data.aws_availability_zones.available.names, 0, length(var.public_subnet_cidrs))
}

module "security_group" {
  source           = "./modules/security_group"
  project_name     = var.project_name
  vpc_id           = module.network.vpc_id
  vpc_cidr         = var.vpc_cidr
  ssh_allowed_cidr = var.ssh_allowed_cidr
}

module "compute" {
  source               = "./modules/compute"
  project_name         = var.project_name
  server_instance_type = var.server_instance_type
  worker_instance_type = var.worker_instance_type
  worker_count         = var.worker_count
  root_volume_size     = var.root_volume_size
  public_subnet_ids    = module.network.public_subnet_ids
  node_sg_id           = module.security_group.node_sg_id
  ssh_public_key_path  = var.ssh_public_key_path
}

# Render the Ansible inventory from node IPs (gitignored, regenerated each apply).
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory/hosts.ini"
  file_permission = "0644"
  content = templatefile("${path.module}/templates/inventory.tmpl", {
    server_public_ip  = module.compute.server_public_ip
    server_private_ip = module.compute.server_private_ip
    workers           = module.compute.workers
  })
}
