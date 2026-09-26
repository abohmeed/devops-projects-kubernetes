# The port map of a Kubernetes cluster, one rule per port, each with a description.

# ---------------------------------------------------------------- bastion
resource "aws_security_group" "bastion" {
  name        = "${var.cluster_id}-bastion"
  description = "SSH entry point, from the admin address only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_id}-bastion"
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  description       = "SSH from the admin address only, never 0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.admin_cidr
}

# ---------------------------------------------------------------- nodes (every node; the ONE group tagged owned)
resource "aws_security_group" "nodes" {
  name        = "${var.cluster_id}-nodes"
  description = "Every Kubernetes node: control plane and workers"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name                                      = "${var.cluster_id}-nodes"
    "kubernetes.io/cluster/${var.cluster_id}" = "owned"
  }
}

resource "aws_vpc_security_group_ingress_rule" "nodes_ssh" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "SSH from the bastion, for ssh -J"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_ingress_rule" "nodes_kubelet" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "kubelet API: the API server reaching kubelets for logs, exec, metrics"
  ip_protocol                  = "tcp"
  from_port                    = 10250
  to_port                      = 10250
  referenced_security_group_id = aws_security_group.nodes.id
}

resource "aws_vpc_security_group_ingress_rule" "nodes_cilium_vxlan" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "Cilium VXLAN overlay: pod-to-pod traffic between nodes"
  ip_protocol                  = "udp"
  from_port                    = 8472
  to_port                      = 8472
  referenced_security_group_id = aws_security_group.nodes.id
}

resource "aws_vpc_security_group_ingress_rule" "nodes_cilium_health" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "Cilium node-to-node health checks"
  ip_protocol                  = "tcp"
  from_port                    = 4240
  to_port                      = 4240
  referenced_security_group_id = aws_security_group.nodes.id
}

# Every node (control plane and workers) is in this group, so one rule covers all node pairs.
# For ICMP, from_port is the ICMP type (8 = echo request) and to_port the code (0).
resource "aws_vpc_security_group_ingress_rule" "nodes_cilium_icmp" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "Cilium node-to-node health probes (ICMP echo)"
  ip_protocol                  = "icmp"
  from_port                    = 8
  to_port                      = 0
  referenced_security_group_id = aws_security_group.nodes.id
}

# ---------------------------------------------------------------- control plane (extra group, untagged)
resource "aws_security_group" "control_plane" {
  name        = "${var.cluster_id}-control-plane"
  description = "Control-plane only ports: API server and etcd"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_id}-control-plane"
  }
}

resource "aws_vpc_security_group_ingress_rule" "control_plane_api" {
  security_group_id = aws_security_group.control_plane.id
  description       = "Kubernetes API: nodes and the load balancer, from inside the VPC"
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_ingress_rule" "control_plane_etcd" {
  security_group_id            = aws_security_group.control_plane.id
  description                  = "etcd client and peer: control-plane nodes only"
  ip_protocol                  = "tcp"
  from_port                    = 2379
  to_port                      = 2380
  referenced_security_group_id = aws_security_group.control_plane.id
}

# ---------------------------------------------------------------- API load balancer
resource "aws_security_group" "api_lb" {
  name        = "${var.cluster_id}-api-lb"
  description = "Network load balancer in front of the Kubernetes API"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_id}-api-lb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "api_lb_admin" {
  security_group_id = aws_security_group.api_lb.id
  description       = "Kubernetes API: kubectl from the admin workstation"
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
  cidr_ipv4         = var.admin_cidr
}

resource "aws_vpc_security_group_ingress_rule" "api_lb_vpc" {
  security_group_id = aws_security_group.api_lb.id
  description       = "Kubernetes API: kubelets and the control plane, from inside the VPC"
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
  cidr_ipv4         = var.vpc_cidr
}

# The load balancer is internet-facing, so its DNS name resolves to public addresses even
# inside the VPC: private nodes reach it through the NAT gateway, arriving from its address.
resource "aws_vpc_security_group_ingress_rule" "api_lb_nat" {
  security_group_id = aws_security_group.api_lb.id
  description       = "Kubernetes API: private nodes, arriving through the NAT gateway"
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
  cidr_ipv4         = "${aws_eip.nat.public_ip}/32"
}

# ---------------------------------------------------------------- egress: all, on every group
resource "aws_vpc_security_group_egress_rule" "all" {
  for_each = {
    bastion       = aws_security_group.bastion.id
    nodes         = aws_security_group.nodes.id
    control_plane = aws_security_group.control_plane.id
    api_lb        = aws_security_group.api_lb.id
  }

  security_group_id = each.value
  description       = "All outbound (image pulls go through the NAT gateway)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
