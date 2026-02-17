# -----------------------------------------------------------------------------
# Windows VMs (no GPU) — build, staging, pixelfarm, runner-win
# -----------------------------------------------------------------------------

locals {
  windows_vms = merge(
    var.ue_build_nodes,
    var.ue_staging_nodes,
    var.pixelfarm_nodes,
    var.runner_win_nodes,
  )

  windows_vm_tags = merge(
    { for k, _ in var.ue_build_nodes      : k => ["windows", "build"] },
    { for k, _ in var.ue_staging_nodes    : k => ["windows", "staging"] },
    { for k, _ in var.pixelfarm_nodes  : k => ["windows", "pixelfarm"] },
    { for k, _ in var.runner_win_nodes : k => ["windows", "runner"] },
  )
}

module "windows_vm" {
  source   = "./modules/proxmox-vm"
  for_each = local.windows_vms

  name           = each.key
  node_name      = each.value.node
  tags           = local.windows_vm_tags[each.key]
  template_id    = var.windows_template_id
  cores          = each.value.cores
  memory_mb      = each.value.memory_mb
  disk_gb        = each.value.disk_gb
  datastore_id   = var.proxmox_hosts[each.value.node].storage_id
  network_bridge = var.network_bridge
  os_type        = "win11"

  # No GPU — only CX6 VF when specified
  pci_devices = each.value.cx6_slot != null ? [{
    device = "hostpci0"
    id     = var.proxmox_hosts[each.value.node].cx6_vfs[each.value.cx6_slot]
    xvga   = false
    pcie   = true
    rombar = true
  }] : []
}
