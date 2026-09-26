packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "= 1.8.2"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  region          = "us-east-1"
  instance_type   = "t3.micro"
  ami_name        = "k8s-node-1.36.4"
  ami_description = "Ubuntu 24.04 + containerd 2.3.6 + kubelet/kubeadm/kubectl 1.36.4"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"]
    most_recent = true
  }

  ssh_username                              = "ubuntu"
  temporary_security_group_source_public_ip = true

  force_deregister      = true
  force_delete_snapshot = true

  tags = {
    Name       = "k8s-node-1.36.4"
    kubernetes = "1.36.4"
    containerd = "2.3.6"
    base_image = "{{ .SourceAMIName }}"
  }
}

build {
  name    = "k8s-node"
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
    environment_vars = [
      "KUBERNETES_MINOR=v1.36",
      "KUBERNETES_VERSION=1.36.4-1.1",
      "CONTAINERD_VERSION=2.3.6-1~ubuntu.24.04~noble",
    ]
    execute_command = "chmod +x {{ .Path }}; sudo {{ .Vars }} bash {{ .Path }}"
    script          = "scripts/k8s-node.sh"
  }
}
