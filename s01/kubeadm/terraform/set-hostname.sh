#!/bin/bash
# Node name = EC2 private DNS name, so the cloud controller can match the node to its instance.
TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
hostnamectl set-hostname "$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-hostname)"
echo "preserve_hostname: true" > /etc/cloud/cloud.cfg.d/99-k8s-hostname.cfg
