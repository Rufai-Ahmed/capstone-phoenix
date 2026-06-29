variable "project_name" {
  description = "Name prefix for all resources."
  type        = string
  default     = "capstone-phoenix"
}

variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region. Matches the team's existing infra (Stockholm)."
  type        = string
  default     = "eu-north-1"
}

# --- Network ---
variable "vpc_cidr" {
  description = "CIDR for the cluster VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per AZ. Nodes live here with public IPs."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

# --- Access ---
variable "ssh_allowed_cidr" {
  description = "Your public IP in CIDR form (e.g. 1.2.3.4/32). Port 22 is open ONLY to this. Find it with: curl -s ifconfig.me"
  type        = string

  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0)) && var.ssh_allowed_cidr != "0.0.0.0/0"
    error_message = "ssh_allowed_cidr must be a valid CIDR and must NOT be 0.0.0.0/0 (the brief forbids opening SSH to the world)."
  }
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key uploaded to the nodes."
  type        = string
  default     = "~/.ssh/capstone-phoenix.pub"
}

# --- Compute ---
variable "server_instance_type" {
  description = "k3s control-plane node size. Runs the API server and Argo CD, so give it 4 GiB."
  type        = string
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "k3s agent node size."
  type        = string
  default     = "t3.small"
}

variable "worker_count" {
  description = "Number of k3s agent (worker) nodes. Brief requires >= 2."
  type        = number
  default     = 2

  validation {
    condition     = var.worker_count >= 2
    error_message = "The brief requires at least 2 workers (3+ nodes total)."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size (GiB) per node."
  type        = number
  default     = 20
}
