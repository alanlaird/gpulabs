#!/bin/bash
# provision.sh — Wait for nodes, write Ansible inventory, run Docker setup playbook
# Called by Terraform null_resource and by 'make provision'
set -e

IP1="${1:?Usage: provision.sh <ip1> <ip2> [ssh_user] [ssh_key]}"
IP2="${2:?Usage: provision.sh <ip1> <ip2> [ssh_user] [ssh_key]}"
SSH_USER="${3:-ubuntu}"
SSH_KEY="${4:-$(dirname "$0")/../id_nccl_docker}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="$BASE_DIR/ansible"
INVENTORY="$ANSIBLE_DIR/inventory.yml"

echo "════════════════════════════════════════════════════════════"
echo "  Provisioning Docker NCCL nodes"
echo "════════════════════════════════════════════════════════════"
echo "  Node 1: $IP1"
echo "  Node 2: $IP2"
echo "════════════════════════════════════════════════════════════"
echo ""

# Step 1: Wait for SSH
echo "Step 1/3  Waiting for nodes to accept SSH..."
"$SCRIPT_DIR/wait-for-nodes.sh" "$IP1" "$IP2" 600 "$SSH_USER" "$SSH_KEY"
echo ""

# Step 2: Write inventory
echo "Step 2/3  Writing Ansible inventory..."
mkdir -p "$ANSIBLE_DIR"
cat > "$INVENTORY" <<EOF
all:
  children:
    gpu_nodes:
      hosts:
        gpu1:
          ansible_host: $IP1
          ansible_user: $SSH_USER
          ansible_ssh_private_key_file: ../id_nccl_docker
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o IdentitiesOnly=yes'
        gpu2:
          ansible_host: $IP2
          ansible_user: $SSH_USER
          ansible_ssh_private_key_file: ../id_nccl_docker
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o IdentitiesOnly=yes'
      vars:
        ansible_python_interpreter: /usr/bin/python3
EOF
echo "  Inventory written: $INVENTORY"
echo ""

# Step 3: Run playbook
echo "Step 3/3  Running Docker setup playbook..."
cd "$ANSIBLE_DIR"

if command -v ansible-playbook &>/dev/null; then
    ansible-playbook -i inventory.yml docker-setup.yml
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  Setup complete!  Docker installed, NCCL image pulled."
    echo "  Run: make test"
    echo "════════════════════════════════════════════════════════════"
else
    echo "ERROR: ansible-playbook not found (brew install ansible)"
    exit 1
fi
