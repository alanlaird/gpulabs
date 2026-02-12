#!/bin/bash
# Generate Ansible inventory from Terraform outputs

set -e

echo "🔧 Generating Ansible inventory from Terraform outputs..."

# Get IPs from terraform (strip /32 CIDR notation)
NODE1_IP=$(terraform output -raw gpu_node_1_ssh | cut -d'@' -f2 | cut -d'/' -f1)
NODE2_IP=$(terraform output -raw gpu_node_2_ssh | cut -d'@' -f2 | cut -d'/' -f1)

echo "📡 Node 1 IP: $NODE1_IP"
echo "📡 Node 2 IP: $NODE2_IP"

# Generate the inventory file
cat > ansible/inventory.yml <<EOF
all:
  children:
    gpu_nodes:
      hosts:
        gpu_node_1:
          ansible_host: $NODE1_IP
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ../id_nebius
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o IdentitiesOnly=yes'
        gpu_node_2:
          ansible_host: $NODE2_IP
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ../id_nebius
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o IdentitiesOnly=yes'
      vars:
        ansible_python_interpreter: /usr/bin/python3
EOF

echo "✅ Ansible inventory generated at ansible/inventory.yml"
