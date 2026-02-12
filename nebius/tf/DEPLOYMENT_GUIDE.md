# Quick Deployment Guide

This guide walks you through deploying two Nebius GPU instances with fully automated image and subnet selection.

## Prerequisites (5 minutes)

### 1. Install Required Tools

```bash
# Install Terraform
# Visit: https://developer.hashicorp.com/terraform/install

# Install Nebius CLI
curl -sSL https://storage.eu-north1.nebius.cloud/cli/install.sh | bash

# Initialize Nebius CLI
nebius profile create

# Install jq (for JSON parsing)
# Ubuntu/Debian:
sudo apt-get install jq

# macOS:
brew install jq
```

### 2. Set Up Authentication

```bash
# Get your API token from: https://console.nebius.com
export NEBIUS_TOKEN="your-token-here"

# Or rely on the Nebius CLI profile (already configured in step 1)
```

## Deployment Steps (3 minutes)

### Step 1: Configure Your Deployment

```bash
# Copy the example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit the file (only 2 required values!)
nano terraform.tfvars
```

Edit these two lines:
```hcl
parent_id      = "project-e00ymp8qpr00qcztrqfhd5"  # Already set for you
ssh_public_key = "YOUR_SSH_PUBLIC_KEY_HERE"       # Add your SSH key
```

Get your SSH key:
```bash
cat ~/.ssh/id_rsa.pub
```

Don't have an SSH key? Generate one:
```bash
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
```

### Step 2: Run Pre-flight Check (Optional but Recommended)

```bash
./preflight-check.sh
```

This verifies:
- ✓ All tools are installed
- ✓ Configuration is valid
- ✓ Scripts can connect to Nebius
- ✓ Images and subnets are available

### Step 3: Initialize Terraform

```bash
# Copy provider configuration
cp .terraformrc ~/.terraformrc

# Initialize Terraform
terraform init
```

Expected output:
```
Terraform has been successfully initialized!
```

### Step 4: Review the Plan

```bash
terraform plan
```

This shows:
- Which image will be automatically selected (latest Ubuntu + CUDA)
- Which subnet will be used (first available)
- All resources that will be created
- Estimated costs

### Step 5: Deploy!

```bash
terraform apply
```

Type `yes` when prompted.

Wait 2-3 minutes for deployment to complete.

## What Happens During Deployment

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Terraform calls scripts/find-latest-image.sh             │
│    → Finds Ubuntu 22.04 with CUDA 12.4 (example)            │
│                                                              │
│ 2. Terraform calls scripts/find-subnet.sh                   │
│    → Finds first available subnet in your project           │
│                                                              │
│ 3. Creates 2 boot disks (100GB SSD each)                    │
│    → Pre-loaded with selected Ubuntu + CUDA image           │
│                                                              │
│ 4. Creates 2 GPU instances (L40S)                           │
│    → Attached to selected subnet                            │
│    → Public IPs assigned automatically                      │
│    → SSH access configured with your key                    │
└─────────────────────────────────────────────────────────────┘
```

## After Deployment

### View Connection Information

```bash
terraform output connection_info
```

You'll see:
```
╔════════════════════════════════════════════════════════════════╗
║                   🚀 GPU INSTANCES READY! 🚀                    ║
╚════════════════════════════════════════════════════════════════╝

📦 Image: Ubuntu 22.04 LTS
🔧 CUDA: 12.4
🌐 Network: default-subnet (10.0.0.0/24)

🔌 CONNECT:
─────────────────────────────────────────────────────────────────
Node 1: ssh ubuntu@1.2.3.4
Node 2: ssh ubuntu@5.6.7.8
```

### Connect to Your Instances

```bash
# Get the SSH commands
terraform output gpu_node_1_ssh
terraform output gpu_node_2_ssh

# Or directly copy from connection_info
ssh ubuntu@<ip-from-output>
```

### Verify GPU Access

Once connected:
```bash
# Check GPU
nvidia-smi

# Check CUDA
nvcc --version

# Check OS
cat /etc/os-release

# View welcome message
cat /etc/motd
```

## What Got Automatically Selected?

View auto-detected resources:

```bash
# See which image was selected
terraform output auto_selected_image

# See which subnet was selected
terraform output auto_selected_subnet
```

Example output:
```json
{
  "image_id": "image-abc123xyz",
  "image_name": "ubuntu-22-04-lts-gpu-cuda-12-4",
  "os_version": "Ubuntu 22.04 LTS",
  "cuda_version": "12.4",
  "detection": "✓ Automatically detected latest Ubuntu CUDA image"
}
```

## Common Next Steps

### Run Your ML Workload

```bash
# Install PyTorch
pip install torch torchvision torchaudio

# Verify GPU access in Python
python3 -c "import torch; print(torch.cuda.is_available())"
```

### Install Additional Tools

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Install NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

### Test GPU Workload

```bash
# Run a simple GPU test
python3 << EOF
import torch
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"CUDA version: {torch.version.cuda}")
print(f"GPU name: {torch.cuda.get_device_name(0)}")
print(f"GPU memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB")
EOF
```

## Customization Options

All in `terraform.tfvars`:

### Use Different GPU

```hcl
# For H100 (more powerful, more expensive)
gpu_platform = "gpu-h100-sxm"
gpu_preset   = "1gpu-16vcpu-200gb"
```

### Change Disk Size

```hcl
boot_disk_size_gb = 500  # Up to 4096 GB
```

### Change Region

```hcl
region = "us-central1"  # Options: eu-north1, us-central1, eu-west1
```

### Custom Instance Names

```hcl
instance_name_prefix = "ml-training"
environment          = "prod"
```

## Troubleshooting

### No Subnets Found

Create a subnet:
```bash
nebius vpc v1 subnet create \
  --parent-id project-e00ymp8qpr00qcztrqfhd5 \
  --name default-subnet \
  --cidr 10.0.0.0/24 \
  --zone eu-north1-a
```

### Scripts Not Working

Make them executable:
```bash
chmod +x scripts/*.sh
chmod +x preflight-check.sh
```

### Authentication Failed

Re-authenticate:
```bash
nebius profile create
```

Or set token:
```bash
export NEBIUS_TOKEN="your-token"
```

### Can't SSH to Instance

Wait 2-3 minutes for boot, then try again. Check status:
```bash
terraform refresh
terraform output connection_info
```

## Clean Up

When you're done, destroy everything:

```bash
terraform destroy
```

Type `yes` to confirm.

This will:
- Delete both GPU instances
- Delete both boot disks
- Stop all charges

## Cost Reminder

| Configuration | Hourly | Daily | Monthly |
|--------------|--------|-------|---------|
| 2× L40S | $3.10 | $74.40 | $2,263 |
| 2× H100 | $4.60 | $110.40 | $3,358 |

**Stop instances when not in use to save money!**

## Support

- **Documentation**: See README.md for detailed information
- **Pre-flight Check**: Run `./preflight-check.sh` to diagnose issues
- **Nebius Docs**: https://docs.nebius.com/
- **Terraform Docs**: https://docs.nebius.com/terraform-provider/

---

**Questions?** Check the README.md or run `./preflight-check.sh` for diagnostics.
