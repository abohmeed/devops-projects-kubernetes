#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Wait until cloud-init has finished its own apt work on first boot
cloud-init status --wait > /dev/null || true

# 1. Kernel modules the container runtime and pod networking rely on
cat <<'EOF' > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# 2. Let the node forward packets between pods and the network
cat <<'EOF' > /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system

# 3. Swap off, now and after every reboot
swapoff -a
sed -i '/\sswap\s/ s/^/#/' /etc/fstab

# 4. containerd from Docker's apt repository
apt-get update
apt-get install -y ca-certificates curl gpg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y "containerd.io=${CONTAINERD_VERSION}"
apt-mark hold containerd.io

# 5. A fresh config: CRI enabled, systemd cgroup driver
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
grep -q 'SystemdCgroup = true' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# 6. kubelet, kubeadm and kubectl from pkgs.k8s.io, pinned and held
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y "kubelet=${KUBERNETES_VERSION}" "kubeadm=${KUBERNETES_VERSION}" "kubectl=${KUBERNETES_VERSION}"
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

# Prove it: containerd answers CRI calls, and the control-plane images are baked in
kubeadm config images pull --kubernetes-version v1.36.4
containerd --version
kubeadm version -o short
