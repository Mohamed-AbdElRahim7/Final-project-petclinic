#!/bin/bash
set -e

# ===== Logging =====
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "════════════════════════════════════════"
echo "User-Data Start: $(date)"
echo "════════════════════════════════════════"

# ===== Basic update =====
apt-get update -y

# ===== Hostname =====
hostnamectl set-hostname ${hostname}
echo "127.0.0.1 ${hostname}" >> /etc/hosts

# ===== Essential tools =====
apt-get install -y \
  curl \
  wget \
  vim \
  git \
  unzip \
  jq \
  apt-transport-https \
  ca-certificates \
  gnupg \
  lsb-release \
  software-properties-common \
  nfs-common

# ===== Disable swap =====
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# ===== Kernel modules =====
cat <<EOF >/etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# ===== sysctl =====
cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# ===== containerd =====
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# ===== Kubernetes repo =====
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | \
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' \
  >/etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

# ===== (اختياري) إعداد volumes للـ etcd / containerd data =====
# حط هنا أي mount / format للأقراص الإضافية لو عندك

# ===== AWS CLI v2 =====
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# ===== CloudWatch Agent =====
cd /tmp
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb || true
rm -f amazon-cloudwatch-agent.deb

# تقدر بعدين تبعت config JSON من Ansible أو يدويًا على:
# /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl ...

echo "════════════════════════════════════════"
echo "User-Data Complete: $(date)"
echo "════════════════════════════════════════"

# ===== Ready marker for Ansible =====
touch /tmp/node-ready
chmod 644 /tmp/node-ready
echo "✅ Node ready for Ansible"
