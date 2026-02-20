# -----------------------------------------------------------------------------
# Windows GPU VMs — ue_content, ue_previs, touch, arnold_fusion, workstation
# -----------------------------------------------------------------------------

locals {
  windows_gpu_vms = merge(
    var.ue_content,
    var.ue_previs,
    var.touch,
    var.arnold_fusion,
    var.workstation,
  )

  windows_gpu_vm_tags = merge(
    { for k, _ in var.ue_content : k => ["windows", "ue", "ue-content", "gpu"] },
    { for k, _ in var.ue_previs : k => ["windows", "ue", "ue-previs", "gpu"] },
    { for k, _ in var.touch : k => ["windows", "touch", "gpu"] },
    { for k, _ in var.arnold_fusion : k => ["windows", "arnold-fusion", "gpu"] },
    { for k, _ in var.workstation : k => ["windows", "workstation", "gpu"] },
  )

  windows_gpu_vm_descriptions = merge(
    { for k, _ in var.ue_content : k => "UE nDisplay content render node" },
    { for k, _ in var.ue_previs : k => "UE nDisplay previs render node" },
    { for k, _ in var.touch : k => "TouchDesigner volumetric content" },
    { for k, _ in var.arnold_fusion : k => "Arnold/Fusion offline render" },
    { for k, _ in var.workstation : k => "Artist workstation" },
  )
}

module "windows_gpu_vm" {
  source   = "../modules/proxmox-vm"
  for_each = local.windows_gpu_vms

  id             = each.value.id
  name           = each.key
  description    = local.windows_gpu_vm_descriptions[each.key]
  node_name      = each.value.node
  tags           = local.windows_gpu_vm_tags[each.key]
  template_id    = var.windows_template_ids[each.value.node]
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
      xvga   = false
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

  # Cloudbase-init sets IP/DNS on first boot
  cloud_init = {
    ip       = each.value.ip
    gateway  = var.network_gateway
    dns      = var.dns_servers
    password = var.windows_admin_password
  }
}
