variable "parent_id" {
  description = "Nebius project ID"
  type        = string
}

variable "region" {
  description = "Nebius region"
  type        = string
  default     = "eu-north1"

  validation {
    condition     = contains(["eu-north1", "eu-west1", "us-central1", "me-west1"], var.region)
    error_message = "Region must be one of: eu-north1, eu-west1, us-central1, me-west1"
  }
}

variable "instance_name_prefix" {
  description = "Prefix for instance names (creates <prefix>-1 and <prefix>-2)"
  type        = string
  default     = "gpu-node"
}

variable "gpu_platform" {
  description = <<-EOT
    GPU platform. Options:
      gpu-l40s-a    L40S + Intel   ~$1.55/hr  (default)
      gpu-h100-sxm  H100 NVLink    ~$2.30/hr
      gpu-h200-sxm  H200 NVLink
  EOT
  type    = string
  default = "gpu-l40s-a"

  validation {
    condition     = contains(["gpu-l40s-a", "gpu-l40s-d", "gpu-h100-sxm", "gpu-h200-sxm", "gpu-b200-sxm", "gpu-b200-sxm-a", "gpu-b300-sxm"], var.gpu_platform)
    error_message = "Invalid GPU platform."
  }
}

variable "gpu_preset" {
  description = "GPU preset (vCPU / RAM / GPU count). Example: 1gpu-8vcpu-32gb"
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
    error_message = "Boot disk must be 50–4096 GiB."
  }
}

variable "ssh_user" {
  description = "SSH username on the instances"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "SSH public key for instance access (your local key)"
  type        = string

  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ", var.ssh_public_key))
    error_message = "Must be a valid SSH public key."
  }
}
