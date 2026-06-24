variable "project_name" {
  type = string
}

variable "server_instance_type" {
  type = string
}

variable "worker_instance_type" {
  type = string
}

variable "worker_count" {
  type = number
}

variable "root_volume_size" {
  type = number
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "node_sg_id" {
  type = string
}

variable "ssh_public_key_path" {
  type = string
}
