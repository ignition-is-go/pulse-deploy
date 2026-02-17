# =============================================================================
# proxmox-lxc module — outputs
# =============================================================================

output "container_id" {
  description = "Proxmox container ID"
  value       = proxmox_virtual_environment_container.this.id
}

output "hostname" {
  description = "Container hostname"
  value       = var.hostname
}
