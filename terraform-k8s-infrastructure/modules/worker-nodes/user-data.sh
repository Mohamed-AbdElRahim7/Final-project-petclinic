#!/bin/bash
set +e   # ⛔ ممنوع توقف على أول error

# ===== Logging =====
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "════════════════════════════════════════"
echo "User-Data Start: $(date)"
echo "════════════════════════════════════════"

# ===== Safe Retry Function =====
retry() {
  local n=1
  local max=6
  local delay=5
  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        echo "Retry $n/$max — command failed: $*"
        n=$((n+1))
        sleep $delay
      else
        echo "Command failed after $max attempts: $*"
        return 1
      fi
    }
  done
}

echo "[STEP] Update system"
retry apt-get update -y

echo "[STEP] Set hostname"
hostnamectl set-hostname ${hostname}
echo "127.0.0.1 ${hostname}" >> /etc/hosts

echo "[STEP] Install essential tools"
retry apt-get install -y \
  curl wget vim git unzip jq \
  apt-transport-https ca-certificates gnupg \
  lsb-release software-properties-common nfs-common

echo "[STEP] Disable swap"
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

echo "[STEP] Load kernel modules"
cat <<EOF >/etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

echo "[STEP] Configure sysctl"
cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

echo "[STEP] Install containerd"
retry apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

echo "[STEP] Install Kubernetes repo"
mkdir -p /etc/apt/keyrings
retry curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

retry apt-get update -y
retry apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

echo "[STEP] Install AWS CLI"
cd /tmp
retry curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
  -o "awscliv2.zip"
retry unzip -q awscliv2.zip
retry ./aws/install
rm -rf aws awscliv2.zip

echo "[STEP] Install CloudWatch Agent"
cd /tmp
retry wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazoncloudwatch-agent.deb
dpkg -i -E amazoncloudwatch-agent.deb || true
rm -f amazoncloudwatch-agent.deb

echo "════════════════════════════════════════"
echo "User-Data Complete: $(date)"
echo "════════════════════════════════════════"

echo "[STEP] Create node-ready marker"
touch /tmp/node-ready
chmod 644 /tmp/node-ready

echo "✅ Node ready for Ansible"
