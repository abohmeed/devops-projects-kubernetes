variable "region" {
  description = "AWS Region for the whole cluster."
  type        = string
}

variable "cluster_id" {
  description = "Cluster name. It becomes the kubernetes.io/cluster/<cluster_id> tag the cloud controller looks for."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC range. Must not overlap the pod subnet 192.168.0.0/16 or the service subnet 10.96.0.0/12."
  type        = string
}

variable "admin_cidr" {
  description = "Your public IP as a /32: the only address that may SSH to the bastion or reach the API load balancer from outside."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_cidr)) && endswith(var.admin_cidr, "/32")
    error_message = "admin_cidr must be your public IP as a /32. Paste the output of: curl -s https://checkip.amazonaws.com, then add /32."
  }
}

variable "ssh_public_key_path" {
  description = "Public key installed on the bastion and every node."
  type        = string
}

variable "control_plane_type" {
  description = "Instance type of the control plane. kubeadm preflight needs 2 vCPUs."
  type        = string
}

variable "worker_type" {
  description = "Instance type of the workers."
  type        = string
}

variable "worker_count" {
  description = "Number of worker instances in the Auto Scaling group."
  type        = number
}
