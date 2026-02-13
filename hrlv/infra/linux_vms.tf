# -----------------------------------------------------------------------------
# Optik (computer vision) VM — Linux + GPU
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_vm" "optik" {
  count = var.optik_vm != null ? 1 : 0

  name      = "optik-01"
  node_name = var.optik_vm.node
  tags      = ["linux", "optik", "gpu"]

  clone {
    vm_id = var.linux_template_id
    full  = true
  }

  cpu {
    cores = var.optik_vm.cores
    type  = "host" # Required for GPU passthrough
  }

  memory {
    dedicated = var.optik_vm.memory_mb
  }

  efi_disk {
    datastore_id = var.vm_storage
    file_format  = "raw"
    type         = "4m"
  }

  disk {
    datastore_id = var.vm_storage
    interface    = "scsi0"
    size         = var.optik_vm.disk_gb
  }

  network_device {
    bridge = var.network_bridge
  }

  hostpci {
    device = "hostpci0"
    id     = var.optik_vm.gpu_pci
    pcie   = true
    rombar = true
    xvga   = true
  }

  machine = "q35"
  bios    = "ovmf"

  initialization {
    ip_config {
      ipv4 {
        address = "${var.optik_vm.ip}/24"
        gateway = var.network_gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      keys = [var.ssh_public_key]
    }
  }

  operating_system {
    type = "l26"
  }

  started = true
  on_boot = true

  lifecycle {
    ignore_changes = [disk[0].size]
  }
}

# -----------------------------------------------------------------------------
# Ansible control plane VM — Linux, no GPU
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_vm" "control_plane" {
  count = var.control_plane_vm != null ? 1 : 0

  name      = "ue-control-plane-01"
  node_name = var.control_plane_vm.node
  tags      = ["linux", "manager"]

  clone {
    vm_id = var.linux_template_id
    full  = true
  }

  cpu {
    cores = var.control_plane_vm.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.control_plane_vm.memory_mb
  }

  disk {
    datastore_id = var.vm_storage
    interface    = "scsi0"
    size         = var.control_plane_vm.disk_gb
  }

  network_device {
    bridge = var.network_bridge
  }

  # No GPU, no OVMF needed — seabios is fine
  bios = "seabios"

  initialization {
    ip_config {
      ipv4 {
        address = "${var.control_plane_vm.ip}/24"
        gateway = var.network_gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      keys = [var.ssh_public_key]
    }
  }

  operating_system {
    type = "l26"
  }

  started = true
  on_boot = true

  lifecycle {
    ignore_changes = [disk[0].size]
  }
}
