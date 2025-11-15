#!/bin/bash
# Script to configure kubectl on bastion after Kubernetes cluster is initialized
# Run this AFTER Ansible has set up the K8s cluster

set -e

echo "==================================="
echo "Kubectl Configuration Setup"
echo "==================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as ubuntu user
if [ "$USER" != "ubuntu" ]; then
    echo -e "${YELLOW}Warning: This script should be run as 'ubuntu' user${NC}"
    echo "Switching to ubuntu user..."
    sudo -u ubuntu bash "$0" "$@"
    exit $?
fi

echo -e "${GREEN}Step 1: Creating .kube directory${NC}"
mkdir -p ~/.kube

echo -e "${GREEN}Step 2: Fetching kubeconfig from master node${NC}"
echo "Please provide the private IP of the first master node:"
read -p "Master-1 IP: " MASTER_IP

if [ -z "$MASTER_IP" ]; then
    echo "Error: Master IP is required"
    exit 1
fi

echo "Copying kubeconfig from master node..."
scp -o StrictHostKeyChecking=no ubuntu@${MASTER_IP}:~/.kube/config ~/.kube/config

if [ $? -eq 0 ]; then
    echo -e "${GREEN}? Kubeconfig copied successfully${NC}"
else
    echo "Error: Failed to copy kubeconfig. Make sure:"
    echo "  1. Master node IP is correct"
    echo "  2. Kubernetes has been initialized on the master"
    echo "  3. SSH keys are properly configured"
    exit 1
fi

echo -e "${GREEN}Step 3: Setting permissions${NC}"
chmod 600 ~/.kube/config

echo -e "${GREEN}Step 4: Testing kubectl connectivity${NC}"
if kubectl cluster-info &> /dev/null; then
    echo -e "${GREEN}? Kubectl is working!${NC}"
    echo ""
    kubectl cluster-info
    echo ""
    echo "Cluster nodes:"
    kubectl get nodes
else
    echo "Warning: kubectl connectivity test failed"
    echo "This might be because:"
    echo "  1. The cluster is still initializing"
    echo "  2. The API server endpoint needs updating"
    echo "You may need to edit ~/.kube/config and update the server URL"
fi

echo ""
echo -e "${GREEN}Step 5: Creating useful aliases${NC}"
cat >> ~/.bashrc <<'EOF'

# Kubectl aliases (if not already present)
if ! grep -q "alias k='kubectl'" ~/.bashrc; then
    alias k='kubectl'
    alias kgp='kubectl get pods'
    alias kgn='kubectl get nodes'
    alias kgs='kubectl get svc'
    alias kd='kubectl describe'
    alias kl='kubectl logs'
    alias kexec='kubectl exec -it'
    
    # Namespace shortcuts
    alias kdev='kubectl config set-context --current --namespace=dev'
    alias ktest='kubectl config set-context --current --namespace=test'
    alias kprod='kubectl config set-context --current --namespace=prod'
    
    # Quick context info
    alias kctx='kubectl config current-context'
    alias kns='kubectl config view --minify --output "jsonpath={..namespace}"'
    
    echo "? Kubectl aliases loaded"
fi
EOF

source ~/.bashrc

echo ""
echo -e "${GREEN}==================================="
echo "? Setup Complete!"
echo "===================================${NC}"
echo ""
echo "Quick Commands:"
echo "  k get nodes              - List all nodes"
echo "  k get pods -A            - List all pods"
echo "  k get ns                 - List namespaces"
echo "  kdev                     - Switch to dev namespace"
echo "  ktest                    - Switch to test namespace"
echo "  kprod                    - Switch to prod namespace"
echo ""
echo "Next steps:"
echo "  1. Verify all nodes are Ready: kubectl get nodes"
echo "  2. Check system pods: kubectl get pods -n kube-system"
echo "  3. Create namespaces: kubectl create ns dev && kubectl create ns test && kubectl create ns prod"
echo ""