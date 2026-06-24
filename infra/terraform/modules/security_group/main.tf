# One security group for every node. The brief's firewall rule:
#   * 22  -> your IP only
#   * 80  -> world  (ingress-nginx)
#   * 443 -> world  (ingress-nginx)
#   * everything else (k3s API 6443, flannel vxlan 8472/udp, kubelet 10250, ...)
#     -> intra-VPC only, NEVER the internet.
resource "aws_security_group" "node" {
  name        = "${var.project_name}-node"
  description = "k3s node traffic"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.project_name}-node" }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.node.id
  description       = "SSH from operator IP only"
  cidr_ipv4         = var.ssh_allowed_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.node.id
  description       = "HTTP -> ingress-nginx"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.node.id
  description       = "HTTPS -> ingress-nginx"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# All node-to-node traffic, restricted to the VPC. This covers the k3s API (6443),
# the flannel VXLAN overlay (8472/udp), kubelet (10250), NodePort range, etc.
# without exposing any of them to the internet.
resource "aws_vpc_security_group_ingress_rule" "intra_vpc" {
  security_group_id = aws_security_group.node.id
  description       = "All intra-VPC node-to-node traffic"
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.node.id
  description       = "All egress"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
