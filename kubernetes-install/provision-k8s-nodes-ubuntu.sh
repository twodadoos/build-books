#!/bin/bash

##################################################################################################################
#
# This script installs and configures the prerequisites for a Kubernetes node (control plane or worker).
# It installs the latest stable Kubernetes packages but does *not* fully provision a functional node or cluster.
#
# After running this script, additional steps are required depending on the node's role:
#
# Control Plane:
#   Initialize the control plane, for example:
#     sudo kubeadm init --control-plane-endpoint=controlNode.example.com
#
#   Deploy a CNI plugin, such as Calico:
#     kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/calico.yaml
#
# Worker Node:
#   Join the node to the existing control plane using the join command provided by kubeadm.
#   Example:
#     sudo kubeadm join controlNode.example.com:6443 --token xt7rtu1.kjer9y5pl4klqxh1 \
#       --discovery-token-ca-cert-hash sha256:0876aa7f45mxhd93wwasf8e6164r6932fr9173c35871a36aw3q
#
# This script prepares most required components for Ubuntu, but additional configuration and validation
# are still needed to complete the cluster setup.
#
##################################################################################################################

set -euo pipefail

LATEST_K8S_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt | sed 's/^v//')
K8S_MAJOR_MINOR=$(echo "$LATEST_K8S_VERSION" | cut -d '.' -f 1,2)
K8S_REPO="https://pkgs.k8s.io/core:/stable:/v${K8S_MAJOR_MINOR}/deb/"

#####################################################
# Backup /etc/fstab file
#####################################################
backupdir="/fstab-backup"

if [[ ! -d "${backupdir}" ]]; then
        mkdir "${backupdir}"
fi

rm -rf "${backupdir}"/*

cp /etc/fstab /fstab-backup/fstab.backup

#####################################################
# Disable swap
#####################################################
swapoff -a
sed -i '/[[:space:]]swap[[:space:]]/ s/^\(.*\)$/#\1/g' /etc/fstab


#####################################################
# Load kernel modules and configure kernel parameters
#####################################################
touch /etc/modules-load.d/containerd.conf
printf "%soverlay\nbr_netfilter\n" > /etc/modules-load.d/containerd.conf
modprobe overlay
modprobe br_netfilter

touch /etc/sysctl.d/kubernetes.conf
cat > /etc/sysctl.d/kubernetes.conf <<EOT
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOT

sysctl --quiet --system 2>/dev/null

###################################################
# Install prerequisites
###################################################
apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
if [ $? -ne 0 ]; then
  echo "Error occurred while installing one of these applications:  gnupg2 software-properties-common apt-transport-https ca-certificates"
  exit 1
fi

###################################################
# Configure Docker repository
###################################################
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

###################################################
# Install and configure containerd
###################################################
apt update
apt install -y containerd.io
containerd config default > /etc/containerd/config.toml 2>&1
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
systemctl restart containerd.service
systemctl enable containerd.service

###################################################
# Install and configure kubernetes
###################################################

curl -fsSL "${K8S_REPO}Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
touch /etc/apt/sources.list.d/kubernetes.list
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] ${K8S_REPO} /" > /etc/apt/sources.list.d/kubernetes.list
apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet.service

