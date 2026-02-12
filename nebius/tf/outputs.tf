output "auto_selected_image" {
  description = "Automatically selected GPU image details"
  value = {
    image_id      = local.image_id
    image_name    = local.image_name
    os_version    = local.os_version
    cuda_version  = local.cuda_version
    detection     = "✓ Automatically detected latest Ubuntu CUDA image"
  }
}

output "auto_selected_subnet" {
  description = "Automatically selected subnet details"
  value = {
    subnet_id   = local.subnet_id
    subnet_name = local.subnet_name
    cidr        = local.subnet_cidr
    detection   = "✓ Automatically detected first available subnet"
  }
}

output "gpu_node_1" {
  description = "GPU Node 1 details"
  value = {
    id          = nebius_compute_v1_instance.gpu_node_1.id
    name        = nebius_compute_v1_instance.gpu_node_1.name
    platform    = nebius_compute_v1_instance.gpu_node_1.resources.platform
    preset      = nebius_compute_v1_instance.gpu_node_1.resources.preset
    public_ip   = try(nebius_compute_v1_instance.gpu_node_1.status.network_interfaces[0].public_ip_address.address, "pending")
    cuda        = local.cuda_version
    os          = local.os_version
  }
}

output "gpu_node_2" {
  description = "GPU Node 2 details"
  value = {
    id          = nebius_compute_v1_instance.gpu_node_2.id
    name        = nebius_compute_v1_instance.gpu_node_2.name
    platform    = nebius_compute_v1_instance.gpu_node_2.resources.platform
    preset      = nebius_compute_v1_instance.gpu_node_2.resources.preset
    public_ip   = try(nebius_compute_v1_instance.gpu_node_2.status.network_interfaces[0].public_ip_address.address, "pending")
    cuda        = local.cuda_version
    os          = local.os_version
  }
}

output "connection_info" {
  description = "How to connect to your GPU instances"
  value = <<-EOT

  ╔════════════════════════════════════════════════════════════════╗
  ║                   🚀 GPU INSTANCES READY! 🚀                    ║
  ╚════════════════════════════════════════════════════════════════╝

  📦 Image: ${local.os_version}
  🔧 CUDA: ${local.cuda_version}
  🌐 Network: ${local.subnet_name} (${local.subnet_cidr})

  🤖 ANSIBLE: Automatic configuration has been applied!
     • /etc/hosts with cluster member short names
     • SSH keys for passwordless cluster communication
     • Custom shell prompts showing node names

  🔌 CONNECT:
  ─────────────────────────────────────────────────────────────────
  Node 1: ssh ${var.ssh_user}@${try(nebius_compute_v1_instance.gpu_node_1.status.network_interfaces[0].public_ip_address.address, "PENDING")}
  Node 2: ssh ${var.ssh_user}@${try(nebius_compute_v1_instance.gpu_node_2.status.network_interfaces[0].public_ip_address.address, "PENDING")}

  From any node, SSH to others: ssh gpu1 or ssh gpu2

  ⚡ VERIFY GPU:
  ─────────────────────────────────────────────────────────────────
  nvidia-smi              # Check GPU status
  nvcc --version          # Check CUDA version

  💰 COST: $3.10/hour ($74.40/day)
  🗑️  DESTROY: terraform destroy

  EOT
}

output "gpu_node_1_ssh" {
  description = "SSH command for node 1"
  value       = "ssh ${var.ssh_user}@${try(nebius_compute_v1_instance.gpu_node_1.status.network_interfaces[0].public_ip_address.address, "PENDING")}"
}

output "gpu_node_2_ssh" {
  description = "SSH command for node 2"
  value       = "ssh ${var.ssh_user}@${try(nebius_compute_v1_instance.gpu_node_2.status.network_interfaces[0].public_ip_address.address, "PENDING")}"
}

output "cost_estimate" {
  description = "Estimated costs"
  value = {
    platform          = var.gpu_platform
    preset            = var.gpu_preset
    per_instance      = "$1.55/hour (L40S) or $2.30/hour (H100)"
    total_hourly      = "$3.10/hour (both instances, L40S)"
    total_daily       = "$74.40/day"
    total_monthly     = "$2,263/month"
    note              = "Costs vary by GPU type. Stop instances when not in use!"
  }
}

output "quick_commands" {
  description = "Useful commands for managing your instances"
  value = <<-EOT
  
  📋 QUICK COMMANDS:
  ──────────────────────────────────────────────────────────────
  
  # Show all outputs again
  terraform output
  
  # Get just the SSH commands
  terraform output gpu_node_1_ssh
  terraform output gpu_node_2_ssh
  
  # Show detected image info
  terraform output auto_selected_image
  
  # Show detected subnet info
  terraform output auto_selected_subnet
  
  # Destroy everything (stop charges)
  terraform destroy
  
  # Refresh state (if instances were modified outside Terraform)
  terraform refresh
  
  EOT
}
