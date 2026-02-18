# =============================================================================
# proxmox-lxc module — single LXC container resource
# =============================================================================

resource "proxmox_virtual_environment_container" "this" {
  vm_id         = var.id
  description   = var.description
  node_name     = var.node_name
  tags          = var.tags
  started         = var.started
  start_on_boot   = var.start_on_boot
  unprivileged    = var.unprivileged
  protection      = var.protection

  operating_system {
    template_file_id = var.template_file_id
    type             = var.os_type
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.datastore_id
    size         = var.disk_gb
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = "${var.ip}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      keys = var.ssh_keys
    }
  }

  lifecycle {
    ignore_changes = [disk[0].size]
  }
}
