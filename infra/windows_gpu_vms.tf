# -----------------------------------------------------------------------------
# Windows GPU VMs — ue-render, touch, arnold, workstation
# -----------------------------------------------------------------------------

locals {
  windows_gpu_vms = merge(
    var.ue_render_nodes,
    var.touch_nodes,
    var.arnold_nodes,
    var.workstations,
  )

  windows_gpu_vm_tags = merge(
    { for k, _ in var.ue_render_nodes : k => ["windows", "ue-render", "gpu"] },
    { for k, _ in var.touch_nodes     : k => ["windows", "touch", "gpu"] },
    { for k, _ in var.arnold_nodes    : k => ["windows", "arnold", "gpu"] },
    { for k, _ in var.workstations    : k => ["windows", "workstation", "gpu"] },
  )
}

module "windows_gpu_vm" {
  source   = "./modules/proxmox-vm"
  for_each = local.windows_gpu_vms

  name           = each.key
  node_name      = each.value.node
  tags           = local.windows_gpu_vm_tags[each.key]
  template_id    = var.windows_template_id
  cores          = each.value.cores
  memory_mb      = each.value.memory_mb
  disk_gb        = each.value.disk_gb
  datastore_id   = var.proxmox_hosts[each.value.node].storage_id
  network_bridge = var.network_bridge
  os_type        = "win11"

  pci_devices = concat(
    # GPUs — xvga only on the first GPU
    [for i, slot in each.value.gpu_slots : {
      device = "hostpci${i}"
      id     = var.proxmox_hosts[each.value.node].gpus[slot]
      xvga   = i == 0
      pcie   = true
      rombar = true
    }],
    # CX6 VF — next hostpci slot after GPUs
    each.value.cx6_slot != null ? [{
      device = "hostpci${length(each.value.gpu_slots)}"
      id     = var.proxmox_hosts[each.value.node].cx6_vfs[each.value.cx6_slot]
      xvga   = false
      pcie   = true
      rombar = true
    }] : [],
  )
}
