terraform {
  required_version = "~> 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # tested 6.66.0; .terraform.lock.hcl is committed
    }
  }

  # The bucket is passed at init time: terraform init -backend-config="bucket=${BUCKET}"
  backend "s3" {
    key          = "kubeadm/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "kubeadm-on-aws"
    }
  }
}
