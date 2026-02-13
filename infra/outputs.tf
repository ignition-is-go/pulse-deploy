# -----------------------------------------------------------------------------
# Outputs — feed into Ansible inventory or just inspect after apply
# -----------------------------------------------------------------------------

output "ue_nodes" {
  description = "UE render node names and IPs"
  value = {
    for name, node in var.ue_nodes : name => {
      ip       = node.ip
      rivermax = node.rivermax
      vm_id    = proxmox_virtual_environment_vm.ue_node[name].vm_id
    }
  }
}

output "arnold_nodes" {
  description = "Arnold render node names and IPs"
  value = {
    for name, node in var.arnold_nodes : name => {
      ip    = node.ip
      vm_id = proxmox_virtual_environment_vm.arnold_node[name].vm_id
    }
  }
}

output "optik" {
  description = "Optik VM IP"
  value       = var.optik_vm != null ? var.optik_vm.ip : null
}

output "control_plane" {
  description = "Ansible control plane VM IP"
  value       = var.control_plane_vm != null ? var.control_plane_vm.ip : null
}

output "rship_nodes" {
  description = "rship LXC container IPs"
  value = {
    for name, node in var.rship_nodes : name => {
      ip = node.ip
    }
  }
}

output "rship_control" {
  description = "rship control plane LXC IP"
  value       = var.rship_control != null ? var.rship_control.ip : null
}

# Generate an Ansible-compatible inventory snippet
output "ansible_inventory_snippet" {
  description = "Paste into inventory/hosts.yml or use as reference"
  value = templatefile("${path.module}/templates/ansible-inventory.tpl", {
    ue_nodes      = var.ue_nodes
    arnold_nodes  = var.arnold_nodes
    optik_ip      = var.optik_vm != null ? var.optik_vm.ip : null
    control_ip    = var.control_plane_vm != null ? var.control_plane_vm.ip : null
    rship_nodes   = var.rship_nodes
    rship_cp_ip   = var.rship_control != null ? var.rship_control.ip : null
  })
}
