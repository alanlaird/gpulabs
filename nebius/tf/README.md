# Nebius GPU Nodes - Fully Automated Terraform Configuration

**Zero-configuration deployment** of two NVIDIA L40S GPU instances with automatic image and subnet selection.

## 🚀 Key Features

| Feature | Description |
|---------|-------------|
| 🤖 **Fully Automated** | Automatically finds latest Ubuntu CUDA image and selects subnet |
| ⚡ **Zero Config** | Only requires project ID and SSH key |
| 💰 **Cost-Effective** | L40S GPUs at $1.55/hour each ($3.10 total) |
| 🔒 **Validated** | Input validation ensures configuration correctness |
| 📊 **Detailed Outputs** | Shows exactly what was auto-selected |

## 📋 What Gets Automated

✅ **Image Selection**: Automatically finds the latest Ubuntu image with the newest CUDA version  
✅ **Subnet Selection**: Automatically selects the first available subnet in your project  
✅ **GPU Configuration**: Optimized defaults for L40S (most cost-effective)  
✅ **Network Setup**: Public IPs and SSH access configured automatically  

## 🎯 Quick Start (3 Commands)

### 1. Configure

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set only TWO required values:
```hcl
parent_id      = "project-e00ymp8qpr00qcztrqfhd5"  # Your project (already set)
ssh_public_key = "ssh-rsa AAAAB3... you@email.com" # Your SSH key
```

Get your SSH key:
```bash
cat ~/.ssh/id_rsa.pub
```

### 2. Deploy

```bash
# Set up provider registry
cp .terraformrc ~/.terraformrc

# Initialize and deploy
terraform init
terraform apply
```

### 3. Connect

```bash
# Terraform will show you the SSH commands
terraform output gpu_node_1_ssh
terraform output gpu_node_2_ssh

# Or just look at the connection_info output
terraform output connection_info
```

That's it! The instances will be ready in 2-3 minutes with the latest Ubuntu and CUDA automatically configured.

## 🔍 How Automation Works

### Image Selection Process

The `scripts/find-latest-image.sh` script:
1. Fetches all public GPU images from Nebius in your region
2. Filters for Ubuntu images with CUDA support
3. Parses CUDA versions and sorts them (descending)
4. Selects the image with the highest CUDA version
5. Returns: image ID, name, OS version, CUDA version, GPU drivers

**Example**: If the region has images with CUDA 12.4, 12.2, and 11.8, it will automatically select the CUDA 12.4 image.

### Subnet Selection Process

The `scripts/find-subnet.sh` script:
1. Fetches all subnets in your project
2. Selects the first available subnet
3. Returns: subnet ID, name, and CIDR

**Note**: If you don't have a subnet, create one first:
```bash
nebius vpc v1 subnet create \
  --parent-id project-e00ymp8qpr00qcztrqfhd5 \
  --name default-subnet \
  --cidr 10.0.0.0/24 \
  --zone eu-north1-a
```

## 📊 What You'll See After Deployment

After running `terraform apply`, you'll see:

```
auto_selected_image = {
  image_id     = "image-abc123xyz"
  image_name   = "ubuntu-22-04-lts-gpu-cuda-12-4"
  os_version   = "Ubuntu 22.04 LTS"
  cuda_version = "12.4"
  detection    = "✓ Automatically detected latest Ubuntu CUDA image"
}

auto_selected_subnet = {
  subnet_id   = "vpcsubnet-xyz789"
  subnet_name = "default-subnet"
  cidr        = "10.0.0.0/24"
  detection   = "✓ Automatically detected first available subnet"
}

connection_info = <<EOT

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

⚡ VERIFY GPU:
─────────────────────────────────────────────────────────────────
nvidia-smi              # Check GPU status
nvcc --version          # Check CUDA version

💰 COST: $3.10/hour ($74.40/day)
🗑️  DESTROY: terraform destroy

EOT
```

## ⚙️ Customization Options

All customization is optional! The defaults are optimized for cost-effectiveness.

### Change Region

```hcl
region = "us-central1"  # Options: eu-north1, us-central1, eu-west1
```

### Change GPU Type

For more powerful H100 GPUs:
```hcl
gpu_platform = "gpu-h100-sxm"       # H100 NVLink: ~$2.30/hr
gpu_preset   = "1gpu-16vcpu-200gb"  # 1 GPU, 16 vCPU, 200GB RAM
```

For newest B200 GPUs (if available):
```hcl
gpu_platform = "gpu-b200-sxm"       # B200 NVLink (newest)
gpu_preset   = "1gpu-16vcpu-200gb"
```

### Increase Storage

```hcl
boot_disk_size_gb = 500  # Default: 100 GiB, Max: 4096 GiB
```

### Custom Instance Names

```hcl
instance_name_prefix = "ml-training"  # Creates: ml-training-1, ml-training-2
environment          = "prod"          # Tag for organization
```

## 🔧 Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| Terraform | Infrastructure provisioning | [Install Guide](https://developer.hashicorp.com/terraform/install) |
| Nebius CLI | API access | [Install Guide](https://docs.nebius.com/cli/) |
| jq | JSON parsing (required) | `apt install jq` or `brew install jq` |

**Set up authentication**:
```bash
export NEBIUS_TOKEN="your-api-token"
```

Get your token from the [Nebius Console](https://console.nebius.com).

## 📁 Project Structure

```
nebius-gpu-terraform/
├── main.tf                      # Main Terraform configuration
├── variables.tf                 # Variable definitions with validation
├── outputs.tf                   # Detailed output information
├── terraform.tfvars.example     # Configuration template
├── .terraformrc                 # Provider registry setup
├── scripts/
│   ├── find-latest-image.sh    # Auto-detects best GPU image
│   └── find-subnet.sh          # Auto-detects available subnet
└── README.md                    # This file
```

## 🎓 Understanding the Deployment

### What Terraform Creates

1. **2 Boot Disks**: 100GB SSD each with Ubuntu + CUDA pre-installed
2. **2 GPU Instances**: L40S GPUs with 8 vCPU and 32GB RAM each
3. **Network Interfaces**: Public IPs for SSH access
4. **Cloud-init Config**: Sets up SSH user and welcome message

### Resource Labels

Every resource gets automatically labeled:
- `environment`: dev/staging/prod
- `purpose`: ml-training
- `managed_by`: terraform
- `cuda`: Detected CUDA version
- `os`: Detected OS version

### Cloud-init Features

Each instance gets:
- SSH user configured automatically
- Custom welcome message (MOTD) showing:
  - Instance name
  - OS and CUDA versions
  - GPU platform and preset
  - Useful commands

## 💡 Common Workflows

### Check What Will Be Deployed

```bash
terraform plan
```

This shows you:
- Which image will be selected
- Which subnet will be used
- What resources will be created

### Deploy Only One Instance

Comment out the second instance in `main.tf`:
```hcl
# resource "nebius_compute_v1_disk" "boot_disk_2" { ... }
# resource "nebius_compute_v1_instance" "gpu_node_2" { ... }
```

Then run `terraform apply`.

### Scale Up to More Instances

Copy the resource blocks and rename:
```hcl
# Add boot_disk_3, gpu_node_3, etc.
```

Or use `count` or `for_each` for dynamic scaling.

### Test Image Selection

Run the script manually:
```bash
cd scripts
./find-latest-image.sh | jq
```

Input (via stdin):
```json
{"region": "eu-north1"}
```

### Test Subnet Selection

```bash
cd scripts
./find-subnet.sh | jq
```

Input (via stdin):
```json
{"project_id": "project-e00ymp8qpr00qcztrqfhd5"}
```

## 🐛 Troubleshooting

### Error: "nebius CLI not found"

**Solution**: Install the Nebius CLI:
```bash
curl -sSL https://storage.eu-north1.nebius.cloud/cli/install.sh | bash
nebius profile create
```

### Error: "jq command not found"

**Solution**: Install jq:
```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq
```

### Error: "No subnets found in project"

**Solution**: Create a subnet first:
```bash
nebius vpc v1 subnet create \
  --parent-id project-e00ymp8qpr00qcztrqfhd5 \
  --name default-subnet \
  --cidr 10.0.0.0/24 \
  --zone eu-north1-a
```

### Error: "No Ubuntu CUDA images found"

**Solution**: Try a different region or check available images manually:
```bash
nebius compute image list-public --region eu-north1
```

### Error: Script execution failed

**Solution**: Make sure scripts are executable:
```bash
chmod +x scripts/*.sh
```

### SSH Connection Refused

**Wait**: Instances take 2-3 minutes to fully boot. Check with:
```bash
terraform refresh
terraform output connection_info
```

### Invalid SSH Key Format

**Solution**: Ensure your key is in the correct format:
```bash
# Check your key format
cat ~/.ssh/id_rsa.pub

# Should start with: ssh-rsa, ssh-ed25519, or ecdsa-sha2-
```

## 💰 Cost Management

### Current Configuration

| Resource | Quantity | Unit Cost | Total |
|----------|----------|-----------|-------|
| L40S GPU (gpu-l40s-a) | 2 | $1.55/hr | $3.10/hr |
| Boot Disk (100GB SSD) | 2 | ~$0.01/hr | ~$0.02/hr |
| **Total** | | | **$3.12/hr** |

### Monthly Estimates

- **Per day**: $74.88
- **Per week**: $524.16
- **Per month (30 days)**: $2,246.40

### Save Money

1. **Stop when not using**:
   ```bash
   terraform destroy  # Destroys everything
   ```

2. **Use H100 only when needed**: H100s are more expensive (~$2.30/hr each)

3. **Commitment discounts**: Contact Nebius sales for 35% off with 3+ month commitments

4. **Scale down**: Run only one instance instead of two

## 🧪 Testing Before Production

### Dry Run

```bash
terraform plan  # Shows what will be created
```

### Deploy with Dev Environment

```hcl
environment = "dev"  # Tag resources as development
```

### Verify After Deployment

```bash
# Check image selection
terraform output auto_selected_image

# Check subnet selection
terraform output auto_selected_subnet

# Test connectivity
ssh ubuntu@$(terraform output -raw gpu_node_1_ssh | awk '{print $NF}')
nvidia-smi
```

## 📚 Additional Resources

- [Nebius Documentation](https://docs.nebius.com/)
- [Nebius Terraform Provider](https://docs.nebius.com/terraform-provider/)
- [Nebius Pricing](https://nebius.com/prices)
- [NVIDIA L40S Specs](https://www.nvidia.com/en-us/data-center/l40s/)
- [NVIDIA H100 Specs](https://www.nvidia.com/en-us/data-center/h100/)

## 🤝 Contributing

Found a bug or have a suggestion? Please:
1. Check the troubleshooting section first
2. Verify your Nebius CLI and jq are up to date
3. Run with `TF_LOG=DEBUG` for detailed logs

## 📄 License

MIT License - Free to use and modify.

---

**Need help?** The automation scripts are in `scripts/` and can be run manually for debugging.
