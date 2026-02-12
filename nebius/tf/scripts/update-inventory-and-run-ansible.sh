#!/bin/bash
set -e

# Update Ansible inventory with current IPs and run the playbook
# This script is called by Terraform after instances are created

IP1="${1:-}"
IP2="${2:-}"
SSH_USER="${3:-ubuntu}"
SSH_KEY="${4:-../id_nebius}"

if [ -z "$IP1" ] || [ -z "$IP2" ]; then
    echo "Usage: $0 <ip1> <ip2> [ssh_user] [ssh_key]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="$TF_DIR/ansible"
INVENTORY_FILE="$ANSIBLE_DIR/inventory.yml"

echo "════════════════════════════════════════════════════════════"
echo "  🔧 Updating Ansible inventory and running playbook"
echo "════════════════════════════════════════════════════════════"
echo "  Node 1 IP: $IP1"
echo "  Node 2 IP: $IP2"
echo "  Inventory: $INVENTORY_FILE"
echo "════════════════════════════════════════════════════════════"
echo ""

# Step 1: Wait for nodes to be ready
echo "📡 Step 1: Waiting for nodes to be ready..."
"$SCRIPT_DIR/wait-for-nodes.sh" "$IP1" "$IP2" 300 "$SSH_USER" "$SSH_KEY"
echo ""

# Step 2: Update inventory file with current IPs
echo "📝 Step 2: Updating Ansible inventory with new IPs..."
echo "  - gpu1: $IP1"
echo "  - gpu2: $IP2"

# Always use relative path for the inventory since ansible runs from ansible/ directory
INVENTORY_SSH_KEY="../id_nebius"

cat > "$INVENTORY_FILE" <<EOF
all:
  children:
    gpu_nodes:
      hosts:
        gpu1:
          ansible_host: $IP1
          ansible_user: $SSH_USER
          ansible_ssh_private_key_file: $INVENTORY_SSH_KEY
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o IdentitiesOnly=yes'
        gpu2:
          ansible_host: $IP2
          ansible_user: $SSH_USER
          ansible_ssh_private_key_file: $INVENTORY_SSH_KEY
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o IdentitiesOnly=yes'
      vars:
        ansible_python_interpreter: /usr/bin/python3
EOF
echo "✅ Inventory updated at: $INVENTORY_FILE"
echo ""

# Step 3: Run Ansible playbook
echo "🚀 Step 3: Running Ansible playbook..."
cd "$ANSIBLE_DIR"

if command -v ansible-playbook &> /dev/null; then
    ansible-playbook -i inventory.yml playbook.yml
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  ✅ Ansible configuration complete!"
    echo "════════════════════════════════════════════════════════════"
else
    echo "⚠️  ansible-playbook not found. Please install Ansible:"
    echo "    brew install ansible"
    echo ""
    echo "  Then run manually:"
    echo "    cd $ANSIBLE_DIR"
    echo "    ansible-playbook -i inventory.yml playbook.yml"
    exit 1
fi
