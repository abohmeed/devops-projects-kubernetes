output "bastion_public_ip" {
  description = "Public IP of the bastion: the one way in (ssh -J ubuntu@<this>)."
  value       = aws_instance.bastion.public_ip
}

output "control_plane_private_ip" {
  description = "Private IP of the control plane."
  value       = aws_instance.control_plane.private_ip
}

output "api_endpoint" {
  description = "DNS name of the API load balancer. kubeadm's controlPlaneEndpoint is this, with :6443."
  value       = aws_lb.api.dns_name
}

output "cluster_id" {
  description = "Cluster name, and the kubernetes.io/cluster/<cluster_id> tag."
  value       = var.cluster_id
}
