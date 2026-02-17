# -----------------------------------------------------------------------------
# Linux GPU VMs — optik
# -----------------------------------------------------------------------------

locals {
  linux_gpu_vms = merge(
    var.optik_nodes,
  )

  linux_gpu_vm_tags = merge(
    { for k, _ in var.optik_nodes : k => ["linux", "optik", "gpu"] },
  )
}

module "linux_gpu_vm" {
  source   = "./modules/proxmox-vm"
  for_each = local.linux_gpu_vms

  name           = each.key
  node_name      = each.value.node
  tags           = local.linux_gpu_vm_tags[each.key]
  template_id    = var.linux_template_id
  cores          = each.value.cores
  memory_mb      = each.value.memory_mb
  disk_gb        = each.value.disk_gb
  datastore_id   = var.proxmox_hosts[each.value.node].storage_id
  network_bridge = var.network_bridge
  os_type        = "l26"

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

  cloud_init = {
    ip       = each.value.ip
    gateway  = var.network_gateway
    dns      = var.dns_servers
    ssh_keys = [var.ssh_public_key]
  }
}
