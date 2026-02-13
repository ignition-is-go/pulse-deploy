# -----------------------------------------------------------------------------
# Windows UE render/previs nodes
#
# Nodes with rivermax=true get a second hostpci device for the CX6 SR-IOV VF.
# The VFs are created on the Proxmox host via switchdev mode + OVS — see
# docs/connectx6-sriov.md for host-side setup.
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_vm" "ue_node" {
  for_each = var.ue_nodes

  name      = each.key
  node_name = each.value.node
  tags      = ["windows", "ue", "render"]

  clone {
    vm_id = var.windows_template_id
    full  = true
  }

  cpu {
    cores = each.value.cores
    type  = "host" # Required for GPU passthrough
  }

  memory {
    dedicated = each.value.memory_mb
  }

  # EFI disk required for OVMF bios
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

  # GPU passthrough — requires root@pam auth
  hostpci {
    device = "hostpci0"
    id     = each.value.gpu_pci
    pcie   = true
    rombar = true
    xvga   = true
  }

  # CX6 SR-IOV VF passthrough — only for rivermax nodes
  dynamic "hostpci" {
    for_each = each.value.rivermax && each.value.cx6_vf_pci != "" ? [each.value.cx6_vf_pci] : []
    content {
      device = "hostpci1"
      id     = hostpci.value
      pcie   = true
      rombar = true
    }
  }

  # q35 required for PCIe passthrough
  machine = "q35"
  bios    = "ovmf"

  operating_system {
    type = "win11"
  }

  started = true
  on_boot = true

  lifecycle {
    ignore_changes = [
      disk[0].size,
    ]
  }
}
