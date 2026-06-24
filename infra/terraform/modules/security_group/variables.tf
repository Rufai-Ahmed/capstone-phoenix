variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  description = "Used to scope node-to-node traffic to the VPC only."
  type        = string
}

variable "ssh_allowed_cidr" {
  type = string
}
