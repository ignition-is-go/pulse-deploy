# =============================================================================
# proxmox-vm module — single VM resource with conditional PCI/cloud-init
# =============================================================================

locals {
  has_pci   = length(var.pci_devices) > 0
  bios      = coalesce(var.override_bios, "seabios")
  cpu_type  = coalesce(var.override_cpu_type, "host")
  needs_efi = local.bios == "ovmf"
  has_init  = var.cloud_init != null
  has_pass  = local.has_init && var.cloud_init.password != null
  has_ssh   = local.has_init && length(var.cloud_init.ssh_keys) > 0
}

resource "proxmox_virtual_environment_vm" "this" {
  vm_id       = var.id
  name        = var.name
  description = var.description
  node_name   = var.node_name
  tags        = var.tags

  scsi_hardware = "virtio-scsi-single"

  clone {
    vm_id = var.template_id
    full  = true
  }

  cpu {
    cores = var.cores
    type  = local.cpu_type
  }

  memory {
    dedicated = var.memory_mb
  }

  # EFI disk — only when override_bios = "ovmf"
  dynamic "efi_disk" {
    for_each = local.needs_efi ? [1] : []
    content {
      datastore_id = var.datastore_id
      file_format  = "raw"
      type         = "4m"
    }
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_gb
    ssd          = true
    discard      = "on"
    iothread     = true
  }

  network_device {
    bridge = var.network_bridge
  }

  # PCI passthrough — zero or more devices
  dynamic "hostpci" {
    for_each = var.pci_devices
    content {
      device  = hostpci.value.device
      id      = hostpci.value.id != "" ? hostpci.value.id : null
      mapping = hostpci.value.mapping != "" ? hostpci.value.mapping : null
      pcie    = hostpci.value.pcie
      rombar  = hostpci.value.rombar
      xvga    = hostpci.value.xvga
    }
  }

  # q35 required for PCIe passthrough
  machine = local.has_pci ? "q35" : null
  bios    = local.bios

  # Cloud-init — only when cloud_init is provided
  dynamic "initialization" {
    for_each = local.has_init ? [1] : []
    content {
      datastore_id = var.datastore_id
      ip_config {
        ipv4 {
          address = "${var.cloud_init.ip}/24"
          gateway = var.cloud_init.gateway
        }
      }

      dns {
        servers = var.cloud_init.dns
      }

      dynamic "user_account" {
        for_each = local.has_pass || local.has_ssh ? [1] : []
        content {
          password = local.has_pass ? var.cloud_init.password : null
          keys     = local.has_ssh ? var.cloud_init.ssh_keys : null
        }
      }
    }
  }

  operating_system {
    type = var.os_type
  }

  started         = var.started
  on_boot         = var.on_boot
  stop_on_destroy = true
  protection      = var.protection

  lifecycle {
    ignore_changes = [disk[0].size]
  }
}
