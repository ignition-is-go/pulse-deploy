# -----------------------------------------------------------------------------
# Windows Arnold/Fusion render nodes
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_vm" "arnold_node" {
  for_each = var.arnold_nodes

  name      = each.key
  node_name = each.value.node
  tags      = ["windows", "arnold", "render"]

  clone {
    vm_id = var.windows_template_id
    full  = true
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory_mb
  }

  efi_disk {
    datastore_id = var.vm_storage
    file_format  = "raw"
    type         = "4m"
  }

  disk {
    datastore_id = var.vm_storage
    interface    = "scsi0"
    size         = each.value.disk_gb
  }

  network_device {
    bridge = var.network_bridge
  }

  hostpci {
    device = "hostpci0"
    id     = each.value.gpu_pci
    pcie   = true
    rombar = true
    xvga   = true
  }

  machine = "q35"
  bios    = "ovmf"

  operating_system {
    type = "win11"
  }

  started = true
  on_boot = true

  lifecycle {
    ignore_changes = [disk[0].size]
  }
}
