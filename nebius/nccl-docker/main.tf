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
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "nebius" {
  # Authentication via environment variable NEBIUS_IAM_TOKEN
  # (the Makefile exports this automatically from nebius iam get-access-token)
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

locals {
  image_id     = data.external.latest_gpu_image.result.image_id
  image_name   = data.external.latest_gpu_image.result.image_name
  cuda_version = data.external.latest_gpu_image.result.cuda_version
  os_version   = data.external.latest_gpu_image.result.os_version

  subnet_id   = data.external.available_subnet.result.subnet_id
  subnet_name = data.external.available_subnet.result.subnet_name
  subnet_cidr = data.external.available_subnet.result.cidr
}

# ── InfiniBand GPU cluster (only created when infiniband_fabric is set) ──────

resource "nebius_compute_v1_gpu_cluster" "ib_cluster" {
  count = var.infiniband_fabric != "" ? 1 : 0

  parent_id         = var.parent_id
  name              = "${var.instance_name_prefix}-ib-cluster"
  infiniband_fabric = var.infiniband_fabric
}

# ── Boot disks ───────────────────────────────────────────────────────────────

resource "nebius_compute_v1_disk" "boot_disk_1" {
  parent_id = var.parent_id
  name      = "${var.instance_name_prefix}-1-boot"

  metadata = {
    name = "${var.instance_name_prefix}-1-boot"
  }

  type            = "NETWORK_SSD"
  size_gibibytes  = var.boot_disk_size_gb
  source_image_id = local.image_id
}

resource "nebius_compute_v1_disk" "boot_disk_2" {
  parent_id = var.parent_id
  name      = "${var.instance_name_prefix}-2-boot"

  metadata = {
    name = "${var.instance_name_prefix}-2-boot"
  }

  type            = "NETWORK_SSD"
  size_gibibytes  = var.boot_disk_size_gb
  source_image_id = local.image_id
}

# ── GPU instances ─────────────────────────────────────────────────────────────

resource "nebius_compute_v1_instance" "gpu_node_1" {
  parent_id = var.parent_id
  name      = "${var.instance_name_prefix}-1"

  metadata = {
    name        = "${var.instance_name_prefix}-1"
    description = "Docker NCCL test node 1 — CUDA ${local.cuda_version} / ${local.os_version}"
    labels = {
      environment = "dev"
      purpose     = "nccl-docker-test"
      managed_by  = "terraform"
    }
  }

  gpu_cluster = var.infiniband_fabric != "" ? {
    id = nebius_compute_v1_gpu_cluster.ib_cluster[0].id
  } : null

  boot_disk = {
    attach_mode = "READ_WRITE"
    type        = "existing_disk"
    existing_disk = {
      id = nebius_compute_v1_disk.boot_disk_1.id
    }
  }

  network_interfaces = [
    {
      name              = "eth0"
      subnet_id         = local.subnet_id
      ip_address        = {}
      public_ip_address = {}
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
        - ${file("${path.module}/id_nccl_docker.pub")}

  write_files:
    - path: /etc/motd
      content: |
        ================================================
        Docker NCCL Test Node 1 — ${var.instance_name_prefix}-1
        CUDA: ${local.cuda_version}  OS: ${local.os_version}
        ================================================
  EOT

  lifecycle {
    ignore_changes = [cloud_init_user_data]
  }
}

resource "nebius_compute_v1_instance" "gpu_node_2" {
  parent_id = var.parent_id
  name      = "${var.instance_name_prefix}-2"

  metadata = {
    name        = "${var.instance_name_prefix}-2"
    description = "Docker NCCL test node 2 — CUDA ${local.cuda_version} / ${local.os_version}"
    labels = {
      environment = "dev"
      purpose     = "nccl-docker-test"
      managed_by  = "terraform"
    }
  }

  gpu_cluster = var.infiniband_fabric != "" ? {
    id = nebius_compute_v1_gpu_cluster.ib_cluster[0].id
  } : null

  boot_disk = {
    attach_mode = "READ_WRITE"
    type        = "existing_disk"
    existing_disk = {
      id = nebius_compute_v1_disk.boot_disk_2.id
    }
  }

  network_interfaces = [
    {
      name              = "eth0"
      subnet_id         = local.subnet_id
      ip_address        = {}
      public_ip_address = {}
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
        - ${file("${path.module}/id_nccl_docker.pub")}

  write_files:
    - path: /etc/motd
      content: |
        ================================================
        Docker NCCL Test Node 2 — ${var.instance_name_prefix}-2
        CUDA: ${local.cuda_version}  OS: ${local.os_version}
        ================================================
  EOT

  lifecycle {
    ignore_changes = [cloud_init_user_data]
  }
}

# ── Ansible provisioner ───────────────────────────────────────────────────────
# Waits for nodes to be SSH-ready, updates inventory, runs Docker setup playbook.

resource "null_resource" "docker_setup" {
  triggers = {
    node1_id = nebius_compute_v1_instance.gpu_node_1.id
    node2_id = nebius_compute_v1_instance.gpu_node_2.id
    node1_ip = split("/", nebius_compute_v1_instance.gpu_node_1.status.network_interfaces[0].public_ip_address.address)[0]
    node2_ip = split("/", nebius_compute_v1_instance.gpu_node_2.status.network_interfaces[0].public_ip_address.address)[0]
  }

  depends_on = [
    nebius_compute_v1_instance.gpu_node_1,
    nebius_compute_v1_instance.gpu_node_2,
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/provision.sh '${split("/", nebius_compute_v1_instance.gpu_node_1.status.network_interfaces[0].public_ip_address.address)[0]}' '${split("/", nebius_compute_v1_instance.gpu_node_2.status.network_interfaces[0].public_ip_address.address)[0]}' '${var.ssh_user}' '${path.module}/id_nccl_docker'"

    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
    }
  }
}
