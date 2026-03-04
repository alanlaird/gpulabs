output "node1_ip" {
  description = "Public IP of GPU node 1"
  value       = try(split("/", nebius_compute_v1_instance.gpu_node_1.status.network_interfaces[0].public_ip_address.address)[0], "pending")
}

output "node2_ip" {
  description = "Public IP of GPU node 2"
  value       = try(split("/", nebius_compute_v1_instance.gpu_node_2.status.network_interfaces[0].public_ip_address.address)[0], "pending")
}

output "connection_info" {
  description = "Node connection details and quick commands"
  value       = <<-EOT

  ════════════════════════════════════════════════════════════
    Docker NCCL Test Cluster — Ready
  ════════════════════════════════════════════════════════════

    Image:    ${local.os_version}
    CUDA:     ${local.cuda_version}
    Platform: ${var.gpu_platform} / ${var.gpu_preset}
    Network:  ${local.subnet_name} (${local.subnet_cidr})

    Node 1:  ssh ${var.ssh_user}@${try(split("/", nebius_compute_v1_instance.gpu_node_1.status.network_interfaces[0].public_ip_address.address)[0], "PENDING")}
    Node 2:  ssh ${var.ssh_user}@${try(split("/", nebius_compute_v1_instance.gpu_node_2.status.network_interfaces[0].public_ip_address.address)[0], "PENDING")}

    make test      # run NCCL all_reduce benchmark (Docker-based)
    make ssh1      # SSH into node 1
    make ssh2      # SSH into node 2
    make destroy   # stop billing

  EOT
}

output "image_info" {
  description = "Auto-selected GPU image details"
  value = {
    image_id     = local.image_id
    image_name   = local.image_name
    os_version   = local.os_version
    cuda_version = local.cuda_version
  }
}
