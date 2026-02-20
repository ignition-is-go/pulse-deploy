# -----------------------------------------------------------------------------
# Windows VMs (no GPU) — ue_build, ue_staging
# -----------------------------------------------------------------------------

locals {
  windows_vms = merge(
    var.ue_build,
    var.ue_staging,
  )

  windows_vm_tags = merge(
    { for k, _ in var.ue_build : k => ["windows", "ue", "ue-build"] },
    { for k, _ in var.ue_staging : k => ["windows", "ue", "ue-staging"] },
  )

  windows_vm_descriptions = merge(
    { for k, _ in var.ue_build : k => "UE cook/package build node" },
    { for k, _ in var.ue_staging : k => "Plastic sync + build distribution" },
  )
}

module "windows_vm" {
  source   = "../modules/proxmox-vm"
  for_each = local.windows_vms

  id             = each.value.id
  name           = each.key
  description    = local.windows_vm_descriptions[each.key]
  node_name      = each.value.node
  tags           = local.windows_vm_tags[each.key]
  template_id    = var.windows_template_ids[each.value.node]
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

  # Cloudbase-init sets IP/DNS on first boot
  cloud_init = {
    ip       = each.value.ip
    gateway  = var.network_gateway
    dns      = var.dns_servers
    password = var.windows_admin_password
  }
}
