region              = "us-east-1"
cluster_id          = "basic-cluster"    # it becomes the cluster tag
vpc_cidr            = "10.240.0.0/16"    # does not overlap the pod subnet 192.168.0.0/16
admin_cidr          = "PASTE-YOUR-IP/32" # curl -s https://checkip.amazonaws.com
ssh_public_key_path = "~/.ssh/id_ed25519.pub"
control_plane_type  = "t3.medium" # kubeadm preflight needs 2 vCPUs
worker_type         = "t3.medium"
worker_count        = 2
