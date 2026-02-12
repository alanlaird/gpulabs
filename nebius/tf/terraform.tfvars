# ============================================================================
# Nebius GPU Nodes - Fully Automated Configuration
# ============================================================================
# 
# This configuration AUTOMATICALLY:
# ✓ Finds the latest Ubuntu image with the newest CUDA version
# ✓ Selects the first available subnet in your project
# ✓ Deploys two identical GPU instances
#
# You only need to provide: Project ID and SSH key!
#
# ============================================================================

# ============================================================================
# REQUIRED: Your Nebius Project ID
# ============================================================================
parent_id = "project-e00ymp8qpr00qcztrqfhd5"

# ============================================================================
# REQUIRED: Your SSH Public Key
# ============================================================================
# Get your SSH public key with: cat ~/.ssh/id_rsa.pub
# Or generate a new one with: ssh-keygen -t rsa -b 4096
#ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E... your-email@example.com"
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA9cdL6Ov+R/SzsPw/gcRHpqvmhN+/GxhWdpZEms7i/N laird@powers.laird.net"

# ============================================================================
# OPTIONAL: Customize Your Setup (uncomment to change defaults)
# ============================================================================

# Region for finding images (default: eu-north1)
# region = "eu-north1"  # Options: eu-north1, us-central1, eu-west1

# Instance name prefix (default: gpu-node, creates gpu-node-1, gpu-node-2)
# instance_name_prefix = "ml-training"

# Environment tag (default: dev)
# environment = "prod"  # Options: dev, staging, prod

# GPU configuration (default: L40S with Intel - most cost-effective)
# gpu_platform = "gpu-l40s-a"      # L40S Intel: $1.55/hr
# gpu_preset   = "1gpu-8vcpu-32gb" # 1 GPU, 8 vCPU, 32GB RAM

# For more powerful H100 GPUs (more expensive):
# gpu_platform = "gpu-h100-sxm"       # H100: ~$2.30/hr
# gpu_preset   = "1gpu-16vcpu-200gb"  # 1 GPU, 16 vCPU, 200GB RAM

# Boot disk size in GiB (default: 100)
# boot_disk_size_gb = 200

# SSH username (default: ubuntu)
# ssh_user = "ubuntu"

# ============================================================================
# AUTOMATION DETAILS
# ============================================================================
#
# IMAGE SELECTION:
# The scripts/find-latest-image.sh script automatically:
# 1. Fetches all public GPU images in your region
# 2. Filters for Ubuntu images with CUDA support
# 3. Sorts by CUDA version (descending)
# 4. Selects the latest one
#
# SUBNET SELECTION:
# The scripts/find-subnet.sh script automatically:
# 1. Fetches all subnets in your project
# 2. Selects the first available one
# 3. Uses it for both instances
#
# If you need a subnet, create one first:
#   nebius vpc v1 subnet create \
#     --parent-id project-e00ymp8qpr00qcztrqfhd5 \
#     --name default-subnet \
#     --cidr 10.0.0.0/24
#
# ============================================================================

# ============================================================================
# COST ESTIMATE (with defaults)
# ============================================================================
# Per instance:  $1.55/hour (L40S) or $2.30/hour (H100)
# Both instances: $3.10/hour (L40S) or $4.60/hour (H100)
# Daily (24h):    ~$74.40 (L40S) or ~$110 (H100)
# Monthly (730h): ~$2,263 (L40S) or ~$3,358 (H100)
#
# Stop instances when not in use to save money!
# ============================================================================
