terraform {
  required_version = ">= 1.0"
  
  required_providers {
    nebius = {
      source  = "terraform-provider.storage.eu-north1.nebius.cloud/nebius/nebius"
      version = ">= 0.5.55"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}

provider "nebius" {
  # Authentication via environment variable NEBIUS_TOKEN
}

# Automatically find the latest Ubuntu CUDA GPU image
data "external" "latest_gpu_image" {
  program = ["bash", "${path.module}/scripts/find-latest-image.sh"]
  
  query = {
    region = var.region
  }
}

# Automatically find the first available subnet
data "external" "available_subnet" {
  program = ["bash", "${path.module}/scripts/find-subnet.sh"]
  
  query = {
    project_id = var.parent_id
  }
}

# Local variables for easy access
locals {
  image_id         = data.external.latest_gpu_image.result.image_id
  image_name       = data.external.latest_gpu_image.result.image_name
  cuda_version     = data.external.latest_gpu_image.result.cuda_version
  os_version       = data.external.latest_gpu_image.result.os_version
  
  subnet_id        = data.external.available_subnet.result.subnet_id
  subnet_name      = data.external.available_subnet.result.subnet_name
  subnet_cidr      = data.external.available_subnet.result.cidr
}

# Boot disk for GPU Instance 1
resource "nebius_compute_v1_disk" "boot_disk_1" {
  parent_id = var.parent_id
  name      = "${var.instance_name_prefix}-1-boot-disk"

  metadata = {
    name = "${var.instance_name_prefix}-1-boot-disk"
  }

  type            = "NETWORK_SSD"
  size_gibibytes  = var.boot_disk_size_gb
  source_image_id = local.image_id
}

# Boot disk for GPU Instance 2
resource "nebius_compute_v1_disk" "boot_disk_2" {
  parent_id = var.parent_id
  name      = "${var.instance_name_prefix}-2-boot-disk"

  metadata = {
    name = "${var.instance_name_prefix}-2-boot-disk"
  }

  type            = "NETWORK_SSD"
  size_gibibytes  = var.boot_disk_size_gb
  source_image_id = local.image_id
}

# GPU Instance 1 - L40S with Intel (most cost-effective)
resource "nebius_compute_v1_instance" "gpu_node_1" {
  parent_id = var.parent_id
  name      = "${var.instance_name_prefix}-1"

  metadata = {
    name        = "${var.instance_name_prefix}-1"
    description = "GPU instance with ${local.cuda_version} on ${local.os_version}"
    labels = {
      environment = var.environment
      purpose     = "ml-training"
      managed_by  = "terraform"
      cuda        = replace(local.cuda_version, ".", "-")
      os          = replace(local.os_version, " ", "-")
    }
  }

  boot_disk = {
    attach_mode = "READ_WRITE"
    type        = "existing_disk"
    existing_disk = {
      id = nebius_compute_v1_disk.boot_disk_1.id
    }
  }

  network_interfaces = [
    {
      name      = "eth0"
      subnet_id = local.subnet_id
      ip_address = {
        # Dynamic IP assignment
      }
      public_ip_address = {
        # Enables public IP for SSH access
      }
    }
  ]

  resources = {
    platform = var.gpu_platform
    preset   = var.gpu_preset
  }

  cloud_init_user_data = <<-EOT
  #cloud-config
  users:
    - name: ${var.ssh_user}
      groups: sudo
      shell: /bin/bash
      sudo: ['ALL=(ALL) NOPASSWD:ALL']
      ssh_authorized_keys:
        - ${var.ssh_public_key}
  
  write_files:
    - path: /etc/motd
      content: |
        ================================================
        Nebius GPU Instance - ${var.instance_name_prefix}-1
        ================================================
        OS: ${local.os_version}
        CUDA: ${local.cuda_version}
        Platform: ${var.gpu_platform}
        Preset: ${var.gpu_preset}
        
        Check GPU: nvidia-smi
        Check CUDA: nvcc --version
        ================================================
  EOT
}

# GPU Instance 2 - L40S with Intel
resource "nebius_compute_v1_instance" "gpu_node_2" {
  parent_id = var.parent_id
  name      = "${var.instance_name_prefix}-2"

  metadata = {
    name        = "${var.instance_name_prefix}-2"
    description = "GPU instance with ${local.cuda_version} on ${local.os_version}"
    labels = {
      environment = var.environment
      purpose     = "ml-training"
      managed_by  = "terraform"
      cuda        = replace(local.cuda_version, ".", "-")
      os          = replace(local.os_version, " ", "-")
    }
  }

  boot_disk = {
    attach_mode = "READ_WRITE"
    type        = "existing_disk"
    existing_disk = {
      id = nebius_compute_v1_disk.boot_disk_2.id
    }
  }

  network_interfaces = [
    {
      name      = "eth0"
      subnet_id = local.subnet_id
      ip_address = {
        # Dynamic IP assignment
      }
      public_ip_address = {
        # Enables public IP for SSH access
      }
    }
  ]

  resources = {
    platform = var.gpu_platform
    preset   = var.gpu_preset
  }

  cloud_init_user_data = <<-EOT
  #cloud-config
  users:
    - name: ${var.ssh_user}
      groups: sudo
      shell: /bin/bash
      sudo: ['ALL=(ALL) NOPASSWD:ALL']
      ssh_authorized_keys:
        - ${var.ssh_public_key}
  
  write_files:
    - path: /etc/motd
      content: |
        ================================================
        Nebius GPU Instance - ${var.instance_name_prefix}-2
        ================================================
        OS: ${local.os_version}
        CUDA: ${local.cuda_version}
        Platform: ${var.gpu_platform}
        Preset: ${var.gpu_preset}
        
        Check GPU: nvidia-smi
        Check CUDA: nvcc --version
        ================================================
  EOT
}
