#!/bin/bash
set -e

# Logging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "════════════════════════════════════════"
echo "User-Data Start: $(date)"
echo "════════════════════════════════════════"

# Update system
apt-get update -y

# Hostname
hostnamectl set-hostname ${hostname}
echo "127.0.0.1 ${hostname}" >> /etc/hosts

# Install essential packages
apt-get install -y \
    curl \
    wget \
    vim \
    git \
    jq \
    unzip \
    nfs-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common

# Disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# sysctl
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Install containerd
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

# Install Kubernetes Components
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' \
  | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

# ----------------------------
# Install CloudWatch Agent
# ----------------------------
echo "► Installing CloudWatch Agent"

cd /tmp
wget https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb

dpkg -i -E ./amazon-cloudwatch-agent.deb || true
rm amazon-cloudwatch-agent.deb

# Create config directory
mkdir -p /opt/aws/amazon-cloudwatch-agent/bin/
mkdir -p /usr/share/collectd/

# Write CloudWatch Agent config
cat <<EOF > /opt/aws/amazon-cloudwatch-agent/bin/config.json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          { "file_path": "/var/log/syslog",   "log_group_name": "petclinic-syslog", "log_stream_name": "{instance_id}/syslog" },
          { "file_path": "/var/log/kern.log", "log_group_name": "petclinic-kernel", "log_stream_name": "{instance_id}/kernel" },
          { "file_path": "/var/log/user-data.log", "log_group_name": "user-data", "log_stream_name": "{instance_id}/user-data" }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "petclinic/metrics",
    "metrics_collected": {
      "cpu": { "measurement": ["usage_idle","usage_iowait","usage_user","usage_system"], "metrics_collection_interval": 30 },
      "disk": { "measurement": ["used_percent"], "metrics_collection_interval": 30 },
      "mem":  { "measurement": ["mem_used_percent"], "metrics_collection_interval": 30 }
    }
  }
}
EOF

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json \
    -s || true

echo "► CloudWatch Agent Installed"

# ----------------------------

echo "════════════════════════════════════════"
echo "User-Data Complete: $(date)"
echo "════════════════════════════════════════"

touch /tmp/node-ready
chmod 644 /tmp/node-ready

echo "✅ Node ready for Ansible"
