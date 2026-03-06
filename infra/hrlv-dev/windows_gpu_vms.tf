# -----------------------------------------------------------------------------
# Windows GPU VMs — ue_content, ue_previs, touch, arnold_fusion, workstation
# -----------------------------------------------------------------------------

locals {
  windows_gpu_vms = merge(
    var.ue_content,
    var.ue_editing,
    var.ue_previs,
    var.ue_plugin_dev,
    var.touch,
    var.arnold_fusion,
    var.workstation,
  )

  windows_gpu_vm_tags = merge(
    { for k, v in var.ue_content : k => concat(["windows", "ue", "ue-content", "gpu"], v.extra_tags) },
    { for k, v in var.ue_editing : k => concat(["windows", "ue", "ue-editing", "gpu"], v.extra_tags) },
    { for k, v in var.ue_previs : k => concat(["windows", "ue", "ue-previs", "gpu"], v.extra_tags) },
    { for k, v in var.ue_plugin_dev : k => concat(["windows", "ue", "ue-plugin-dev", "gpu"], v.extra_tags) },
    { for k, v in var.touch : k => concat(["windows", "touch", "gpu"], v.extra_tags) },
    { for k, v in var.arnold_fusion : k => concat(["windows", "arnold-fusion", "gpu"], v.extra_tags) },
    { for k, v in var.workstation : k => concat(["windows", "workstation", "gpu"], v.extra_tags) },
  )

  windows_gpu_vm_descriptions = merge(
    { for k, _ in var.ue_content : k => "UE nDisplay content render node" },
    { for k, _ in var.ue_editing : k => "UE Concert multi-user editor" },
    { for k, _ in var.ue_previs : k => "UE nDisplay previs render node" },
    { for k, _ in var.ue_plugin_dev : k => "UE plugin development node" },
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
  tags           = sort(local.windows_gpu_vm_tags[each.key])
  template_id    = var.windows_template_ids[each.value.node]
  cores          = each.value.cores
  memory_mb      = each.value.memory_mb
  disk_gb        = each.value.disk_gb
  datastore_id   = var.proxmox_hosts[each.value.node].storage_id
  network_bridge = var.network_bridge
  os_type        = "win11"
  vga_type       = "qxl"
  started        = each.value.started

  pci_devices = concat(
    # GPUs — all functions, ROM-Bar on, PCIe on, no primary GPU
    [for i, slot in each.value.gpu_slots : {
      device = "hostpci${i}"
      id     = var.proxmox_hosts[each.value.node].gpus[slot]
      pcie   = true
      rombar = true
      xvga   = false
    }],
    # CX6 VFs — next hostpci slots after GPUs (media + storage)
    [for i, slot in each.value.cx6_slots : {
      device = "hostpci${length(each.value.gpu_slots) + i}"
      id     = var.proxmox_hosts[each.value.node].cx6_vfs[slot]
      pcie   = true
      rombar = true
      xvga   = false
    }],
  )

  # NUMA pinning — only when numa_node is specified
  cpu_affinity = each.value.cpu_affinity
  numa_config = each.value.numa_node != null ? {
    hostnodes = tostring(each.value.numa_node)
    memory_mb = each.value.memory_mb
  } : null

  # Cloudbase-init sets IP/DNS on first boot
  cloud_init = {
    ip       = each.value.ip
    gateway  = var.network_gateway
    dns      = var.dns_servers
    password = var.windows_admin_password
  }
}
