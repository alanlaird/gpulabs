#!/bin/bash
# Run Ansible playbook on GPU nodes

set -e

echo "🚀 Running Ansible playbook on GPU nodes..."
echo ""

# Generate inventory from Terraform
./generate-ansible-inventory.sh
echo ""

# Run the playbook
cd ansible
ansible-playbook -i inventory.yml playbook.yml "$@"
