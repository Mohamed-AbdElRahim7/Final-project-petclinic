#!/bin/bash
# ============================================
# Generate Ansible Inventory from Terraform
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform-k8s-infrastructure"
ANSIBLE_DIR="$PROJECT_ROOT/ansible-k8s-setup"
INVENTORY_FILE="$ANSIBLE_DIR/inventory/hosts.ini"

echo "============================================"
echo "  Generating Ansible Inventory"
echo "============================================"

# Check if Terraform directory exists
if [ ! -d "$TERRAFORM_DIR" ]; then
    echo "? Error: Terraform directory not found at $TERRAFORM_DIR"
    exit 1
fi

# Check if Terraform state exists
if [ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
    echo "? Error: Terraform state not found. Run 'terraform apply' first."
    exit 1
fi

# Get Terraform outputs
echo "?? Reading Terraform outputs..."
cd "$TERRAFORM_DIR"

BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null || echo "")
MASTER_IPS=$(terraform output -json master_private_ips 2>/dev/null | jq -r '.[]' | tr '\n' ' ')
WORKER_IPS=$(terraform output -json worker_private_ips 2>/dev/null | jq -r '.[]' | tr '\n' ' ')
LB_DNS=$(terraform output -raw master_load_balancer_dns 2>/dev/null || echo "")

if [ -z "$BASTION_IP" ] || [ -z "$MASTER_IPS" ] || [ -z "$WORKER_IPS" ] || [ -z "$LB_DNS" ]; then
    echo "? Error: Failed to get Terraform outputs"
    echo "Bastion IP: $BASTION_IP"
    echo "Master IPs: $MASTER_IPS"
    echo "Worker IPs: $WORKER_IPS"
    echo "LB DNS: $LB_DNS"
    exit 1
fi

echo "? Terraform outputs retrieved:"
echo "   Bastion: $BASTION_IP"
echo "   Masters: $MASTER_IPS"
echo "   Workers: $WORKER_IPS"
echo "   LB: $LB_DNS"

# Generate inventory file
echo ""
echo "?? Generating inventory file..."

cat > "$INVENTORY_FILE" <<EOF
# ============================================
# Kubernetes Cluster Inventory
# Auto-generated on: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# From Terraform outputs
# ============================================

[bastion]
bastion ansible_host=$BASTION_IP ansible_user=ubuntu

[masters]
EOF

# Add masters
MASTER_INDEX=1
for IP in $MASTER_IPS; do
    echo "master-$MASTER_INDEX ansible_host=$IP node_type=master node_index=$MASTER_INDEX" >> "$INVENTORY_FILE"
    MASTER_INDEX=$((MASTER_INDEX + 1))
done

cat >> "$INVENTORY_FILE" <<EOF

[workers]
EOF

# Add workers
WORKER_INDEX=1
for IP in $WORKER_IPS; do
    echo "worker-$WORKER_INDEX ansible_host=$IP node_type=worker node_index=$WORKER_INDEX" >> "$INVENTORY_FILE"
    WORKER_INDEX=$((WORKER_INDEX + 1))
done

cat >> "$INVENTORY_FILE" <<EOF

# First master (for cluster init)
[first_master]
master-1

# Other masters (for HA)
[other_masters]
EOF

# Add other masters
if [ $MASTER_INDEX -gt 2 ]; then
    for i in $(seq 2 $((MASTER_INDEX - 1))); do
        echo "master-$i" >> "$INVENTORY_FILE"
    done
fi

cat >> "$INVENTORY_FILE" <<EOF

# All K8s nodes
[k8s_cluster:children]
masters
workers

# All infrastructure
[all:children]
bastion
k8s_cluster

# ============================================
# Global Variables
# ============================================
[k8s_cluster:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/petclinic-test-key.pem
ansible_python_interpreter=/usr/bin/python3

# Proxy through bastion for private nodes
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -i ~/.ssh/petclinic-test-key.pem -o StrictHostKeyChecking=no ubuntu@$BASTION_IP"'

[masters:vars]
k8s_role=master

[workers:vars]
k8s_role=worker

[bastion:vars]
# No proxy needed for bastion
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

echo "? Inventory file created: $INVENTORY_FILE"

# Update all.yml with control plane endpoint
echo ""
echo "?? Updating all.yml with control plane endpoint..."
ALL_YML="$ANSIBLE_DIR/inventory/group_vars/all.yml"

if [ -f "$ALL_YML" ]; then
    sed -i.bak "s|control_plane_endpoint:.*|control_plane_endpoint: \"$LB_DNS\"|" "$ALL_YML"
    echo "? Updated $ALL_YML"
else
    echo "??  Warning: $ALL_YML not found"
fi

# Create environment file
ENV_FILE="$ANSIBLE_DIR/terraform-outputs.env"
cat > "$ENV_FILE" <<EOF
# Terraform Outputs
# Generated on: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

export BASTION_IP="$BASTION_IP"
export CONTROL_PLANE_ENDPOINT="$LB_DNS"
export MASTER_IPS="$MASTER_IPS"
export WORKER_IPS="$WORKER_IPS"
EOF

echo "? Environment file created: $ENV_FILE"

# Verify inventory
echo ""
echo "?? Verifying inventory..."
cd "$ANSIBLE_DIR"

if command -v ansible-inventory >/dev/null 2>&1; then
    ansible-inventory --list -i "$INVENTORY_FILE" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "? Inventory file is valid"
    else
        echo "? Inventory file validation failed"
        exit 1
    fi
else
    echo "??  ansible-inventory command not found, skipping validation"
fi

# Test SSH connectivity
echo ""
echo "?? Testing SSH connectivity to bastion..."
if ssh -i ~/.ssh/petclinic-test-key.pem -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$BASTION_IP echo "? Bastion is reachable" 2>/dev/null; then
    echo "? Bastion connectivity: OK"
else
    echo "??  Bastion not reachable yet. Wait a few minutes for EC2 to boot."
fi

echo ""
echo "+------------------------------------------------------+"
echo "¦  ? Inventory Generation Complete!                  ¦"
echo "+------------------------------------------------------+"
echo ""
echo "?? Files created:"
echo "   • $INVENTORY_FILE"
echo "   • $ENV_FILE"
echo ""
echo "?? Next steps:"
echo "   1. Test inventory:"
echo "      cd $ANSIBLE_DIR"
echo "      ansible all -i $INVENTORY_FILE -m ping"
echo ""
echo "   2. Run playbooks:"
echo "      ansible-playbook playbooks/01-verify-nodes.yml"
echo "      # or"
echo "      ansible-playbook playbooks/complete-setup.yml"
echo ""