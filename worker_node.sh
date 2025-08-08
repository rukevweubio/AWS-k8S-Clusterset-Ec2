#!/bin/bash
set -e

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <MASTER_IP> <TOKEN> <DISCOVERY_TOKEN_CA_CERT_HASH>"
  echo "Example: $0 10.0.1.239 qa8vsk.g5b4vkcwie9o6f1f sha256:c77ff4be6236935dffbdae4891bfc82ad8f051677cbd6dd2238e55ebba9fff7f"
  exit 1
fi

MASTER_IP=$1
TOKEN=$2
DISCOVERY_TOKEN_CA_CERT_HASH=$3

echo "Updating system packages..."
apt-get update
apt-get upgrade -y

echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "Loading kernel modules..."
tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

echo "Setting sysctl params for Kubernetes networking..."
tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

echo "Installing dependencies..."
apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

echo "Setting up Docker repository and installing containerd..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

apt update
apt install -y containerd.io

echo "Configuring containerd..."
containerd config default | tee /etc/containerd/config.toml >/dev/null 2>&1
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

echo "Adding Kubernetes apt repo and installing kubelet, kubeadm, kubectl..."
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

echo "Joining the Kubernetes cluster..."
kubeadm join ${MASTER_IP}:6443 --token ${TOKEN} --discovery-token-ca-cert-hash ${DISCOVERY_TOKEN_CA_CERT_HASH}

echo "Worker node setup and join complete."
