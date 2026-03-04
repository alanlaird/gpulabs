# ============================================================================
# Nebius Docker NCCL Test Nodes — Configuration
# ============================================================================
#
# Two minimal-cost GPU nodes for Docker-based NCCL bandwidth testing.
# Ansible installs Docker + NVIDIA Container Toolkit on both nodes.
#
# ============================================================================

# ============================================================================
# REQUIRED: Your Nebius Project ID
# ============================================================================
parent_id = "project-e00ymp8qpr00qcztrqfhd5"

# ============================================================================
# REQUIRED: Your SSH Public Key
# ============================================================================
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA9cdL6Ov+R/SzsPw/gcRHpqvmhN+/GxhWdpZEms7i/N laird@powers.laird.net"

# ============================================================================
# OPTIONAL: Customize (uncomment to change defaults)
# ============================================================================

# GPU configuration — minimal cost defaults
# gpu_platform = "gpu-l40s-a"       # L40S Intel: ~$1.55/hr (default)
# gpu_preset   = "1gpu-8vcpu-32gb"  # 1 GPU, 8 vCPU, 32GB RAM (default)

# Instance naming
# instance_name_prefix = "nccl-docker"

# Boot disk (needs room for Docker images ~10GB)
# boot_disk_size_gb = 100

# ============================================================================
# COST ESTIMATE
# ============================================================================
# Per instance:   $1.55/hour (L40S, 1-GPU preset)
# Both instances: $3.10/hour
# Remember: run 'make destroy' when done to stop billing!
# ============================================================================
