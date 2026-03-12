# -----------------------------------------------------------------------------
# Linux GPU VMs — optik
# -----------------------------------------------------------------------------

locals {
  linux_gpu_vms = merge(
    var.optik,
  )

  linux_gpu_vm_tags = merge(
    { for k, _ in var.optik : k => ["linux", "optik", "gpu"] },
  )

  linux_gpu_vm_descriptions = merge(
    { for k, _ in var.optik : k => "Optik computer vision" },
  )
}

module "linux_gpu_vm" {
  source   = "../modules/proxmox-vm"
  for_each = local.linux_gpu_vms

  id             = each.value.id
  name           = each.key
  description    = local.linux_gpu_vm_descriptions[each.key]
  node_name      = each.value.node
  tags           = sort(local.linux_gpu_vm_tags[each.key])
  template_id    = var.linux_template_ids[each.value.node]
  cores          = each.value.cores
  memory_mb      = each.value.memory_mb
  disk_gb        = each.value.disk_gb
  datastore_id   = var.proxmox_hosts[each.value.node].storage_id
  network_bridge = var.network_bridge
  os_type        = "l26"
  started        = each.value.started

  pci_devices = concat(
    # GPUs — xvga only on the first GPU
    [for i, slot in each.value.gpu_slots : {
      device = "hostpci${i}"
      id     = var.proxmox_hosts[each.value.node].gpus[slot]
      xvga   = false
      pcie   = true
      rombar = true
    }],
    # CX6 VFs — next hostpci slots after GPUs (media + storage)
    [for i, offset in each.value.cx6_vf_offsets : {
      device = "hostpci${length(each.value.gpu_slots) + i}"
      id     = var.proxmox_hosts[each.value.node].cx6_vfs[each.value.cx6_card * local.cx6_vfs_per_card[each.value.node] + offset]
      xvga   = false
      pcie   = true
      rombar = true
    }],
  )

  cloud_init = {
    ip       = each.value.ip
    gateway  = var.network_gateway
    dns      = var.dns_servers
    ssh_keys = [var.ssh_public_key]
  }
}
