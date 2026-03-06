# -----------------------------------------------------------------------------
# Windows VMs (no GPU) — ue_staging, ue_runner
# -----------------------------------------------------------------------------

locals {
  windows_vms = merge(
    var.ue_runner,
    var.ue_staging,
  )

  windows_vm_tags = merge(
    { for k, _ in var.ue_runner : k => ["windows", "ue", "ue-runner"] },
    { for k, _ in var.ue_staging : k => ["windows", "ue", "ue-staging"] },
  )

  windows_vm_descriptions = merge(
    { for k, _ in var.ue_runner : k => "Headless UE automation runner" },
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
  tags           = sort(local.windows_vm_tags[each.key])
  template_id    = var.windows_template_ids[each.value.node]
  cores          = each.value.cores
  memory_mb      = each.value.memory_mb
  disk_gb        = each.value.disk_gb
  datastore_id   = var.proxmox_hosts[each.value.node].storage_id
  network_bridge = var.network_bridge
  os_type        = "win11"
  started        = each.value.started

  # No GPU — only CX6 VFs when specified
  pci_devices = [for i, slot in each.value.cx6_slots : {
    device = "hostpci${i}"
    id     = var.proxmox_hosts[each.value.node].cx6_vfs[slot]
    xvga   = false
    pcie   = true
    rombar = true
  }]

  # Cloudbase-init sets IP/DNS on first boot
  cloud_init = {
    ip       = each.value.ip
    gateway  = var.network_gateway
    dns      = var.dns_servers
    password = var.windows_admin_password
  }
}
