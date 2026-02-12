#!/bin/bash
set -e

# Sync Ansible inventory with current Terraform state
# Usage: ./sync-inventory.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="$TF_DIR/ansible"
INVENTORY_FILE="$ANSIBLE_DIR/inventory.yml"

cd "$TF_DIR"

echo "════════════════════════════════════════════════════════════"
echo "  🔄 Syncing Ansible inventory from Terraform state"
echo "════════════════════════════════════════════════════════════"

# Extract IPs from Terraform state
IP1=$(terraform state show nebius_compute_v1_instance.gpu_node_1 2>/dev/null | \
      grep 'address.*=' | grep -v allocation_id | tail -1 | \
      sed 's/.*= "\([^/]*\).*/\1/')

IP2=$(terraform state show nebius_compute_v1_instance.gpu_node_2 2>/dev/null | \
      grep 'address.*=' | grep -v allocation_id | tail -1 | \
      sed 's/.*= "\([^/]*\).*/\1/')

if [ -z "$IP1" ] || [ -z "$IP2" ]; then
    echo "❌ Error: Could not extract IPs from Terraform state"
    echo "   Make sure you've run 'terraform apply' first"
    exit 1
fi

echo "  Node 1: $IP1"
echo "  Node 2: $IP2"
echo ""

# Update inventory file
cat > "$INVENTORY_FILE" <<EOF
all:
  children:
    gpu_nodes:
      hosts:
        gpu1:
          ansible_host: $IP1
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ../id_nebius
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o IdentitiesOnly=yes'
        gpu2:
          ansible_host: $IP2
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ../id_nebius
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o IdentitiesOnly=yes'
      vars:
        ansible_python_interpreter: /usr/bin/python3
EOF

echo "✅ Inventory updated at: $INVENTORY_FILE"
echo ""
echo "To run Ansible now:"
echo "  cd $ANSIBLE_DIR"
echo "  ansible-playbook -i inventory.yml playbook.yml"
echo "════════════════════════════════════════════════════════════"
