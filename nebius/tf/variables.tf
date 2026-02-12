variable "parent_id" {
  description = "Parent container ID (project/folder) in Nebius"
  type        = string
}

variable "region" {
  description = "Nebius region for finding public images"
  type        = string
  default     = "eu-north1"
  
  validation {
    condition     = contains(["eu-north1", "us-central1", "eu-west1"], var.region)
    error_message = "Region must be one of: eu-north1, us-central1, eu-west1"
  }
}

variable "instance_name_prefix" {
  description = "Prefix for instance names (will be suffixed with -1, -2)"
  type        = string
  default     = "gpu-node"
  
  validation {
    condition     = length(var.instance_name_prefix) > 0 && length(var.instance_name_prefix) <= 50
    error_message = "Instance name prefix must be between 1 and 50 characters."
  }
}

variable "environment" {
  description = "Environment tag for instances (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "gpu_platform" {
  description = <<-EOT
    GPU platform to use. Options:
    - gpu-l40s-a: L40S with Intel (most cost-effective at $1.55/hr)
    - gpu-l40s-d: L40S with AMD
    - gpu-h100-sxm: H100 with NVLink
    - gpu-h200-sxm: H200 with NVLink
    - gpu-b200-sxm: B200 with NVLink (newest)
  EOT
  type        = string
  default     = "gpu-l40s-a"
  
  validation {
    condition     = contains(["gpu-l40s-a", "gpu-l40s-d", "gpu-h100-sxm", "gpu-h200-sxm", "gpu-b200-sxm", "gpu-b200-sxm-a", "gpu-b300-sxm"], var.gpu_platform)
    error_message = "Invalid GPU platform. See variable description for valid options."
  }
}

variable "gpu_preset" {
  description = <<-EOT
    GPU preset defining vCPU, RAM, and GPU count. Options for L40S:
    - 1gpu-8vcpu-32gb: $1.55/hr (recommended for most workloads)
    - 1gpu-40vcpu-160gb: Higher CPU/RAM configuration
    
    For H100/H200:
    - 1gpu-16vcpu-200gb: Single GPU configuration
    - 8gpu-128vcpu-1600gb: Full 8-GPU configuration
  EOT
  type        = string
  default     = "1gpu-8vcpu-32gb"
  
  validation {
    condition     = can(regex("^[0-9]+gpu-[0-9]+vcpu-[0-9]+gb$", var.gpu_preset))
    error_message = "Preset must follow pattern: XgpuYvcpuZgb (e.g., 1gpu-8vcpu-32gb)"
  }
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GiB"
  type        = number
  default     = 100
  
  validation {
    condition     = var.boot_disk_size_gb >= 50 && var.boot_disk_size_gb <= 4096
    error_message = "Boot disk size must be between 50 and 4096 GiB."
  }
}

variable "ssh_user" {
  description = "Username for SSH access"
  type        = string
  default     = "ubuntu"
  
  validation {
    condition     = length(var.ssh_user) > 0 && can(regex("^[a-z_][a-z0-9_-]*[$]?$", var.ssh_user))
    error_message = "SSH user must be a valid Linux username."
  }
}

variable "ssh_public_key" {
  description = "SSH public key for instance access (required)"
  type        = string
  
  validation {
    condition     = length(var.ssh_public_key) > 0 && can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ", var.ssh_public_key))
    error_message = "SSH public key must be a valid SSH public key starting with ssh-rsa, ssh-ed25519, or ecdsa-sha2-*"
  }
}
