# For both Control Plane and Worker nodes

## Pre-deployment

1.  Backup /etc/fstab file
```
sudo mkdir -p /fstab-backup/ && cp /etc/fstab /fstab-backup/fstab.backup
```
2.  Disable Swap
```
sudo swapoff -a && sed -i '/[[:space:]]swap[[:space:]]/ s/^\(.*\)$/#\1/g' /etc/fstab
```
3.  Load kernel modules and configure kernel parameters
```
sudo bash -c 'cat > /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF'
sudo modprobe overlay br_netfilter
```

```
sudo bash -c 'cat > /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF'
```
```
sysctl --quiet --system 2>/dev/null
```
4.  Install prerequisite applications
```
apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
```
5.  Configure Docker repository
```
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```
6.  Configure Kubernetes repository
```
sudo bash -c '
LATEST_K8S_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt | sed "s/^v//")
K8S_MAJOR_MINOR=$(echo "$LATEST_K8S_VERSION" | cut -d "." -f 1,2)
K8S_REPO="https://pkgs.k8s.io/core:/stable:/v${K8S_MAJOR_MINOR}/deb/"
curl -fsSL "${K8S_REPO}Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
touch /etc/apt/sources.list.d/kubernetes.list
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] ${K8S_REPO} /" > /etc/apt/sources.list.d/kubernetes.list
'
```
7.  Update apt packages
```
apt update
```
## Deployment
1.  Install and configure containerd
```
apt update

apt install -y containerd.io

containerd config default > /etc/containerd/config.toml 2>&1

sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

systemctl restart containerd.service

systemctl enable containerd.service
```

3.  Install and configure kubernetes
```
apt update

apt install -y kubelet kubeadm kubectl

apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet.service
```
# For Control Plane
