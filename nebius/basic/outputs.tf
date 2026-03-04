output "node1_ip" {
  description = "Public IP of GPU node 1"
  value       = split("/", nebius_compute_v1_instance.gpu_node_1.status.network_interfaces[0].public_ip_address.address)[0]
}

output "node2_ip" {
  description = "Public IP of GPU node 2"
  value       = split("/", nebius_compute_v1_instance.gpu_node_2.status.network_interfaces[0].public_ip_address.address)[0]
}

output "image_info" {
  description = "GPU image selected"
  value = {
    image_id     = local.image_id
    image_name   = local.image_name
    cuda_version = local.cuda_version
    os_version   = local.os_version
  }
}

output "connection_info" {
  description = "SSH connection commands"
  value = <<-EOT

    Node 1: ssh -i id_basic ${var.ssh_user}@${split("/", nebius_compute_v1_instance.gpu_node_1.status.network_interfaces[0].public_ip_address.address)[0]}
    Node 2: ssh -i id_basic ${var.ssh_user}@${split("/", nebius_compute_v1_instance.gpu_node_2.status.network_interfaces[0].public_ip_address.address)[0]}

    Platform: ${var.gpu_platform} / ${var.gpu_preset}
    Image:    ${local.image_name}  (CUDA ${local.cuda_version})
  EOT
}
