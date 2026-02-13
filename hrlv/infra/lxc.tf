# -----------------------------------------------------------------------------
# rship worker LXC containers
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_container" "rship_node" {
  for_each = var.rship_nodes

  description   = "rship worker node"
  node_name     = each.value.node
  tags          = ["linux", "lxc", "rship"]
  started       = true
  start_on_boot = true
  unprivileged  = true

  operating_system {
    template_file_id = var.lxc_template
    type             = "debian"
  }

  cpu {
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory_mb
  }

  disk {
    datastore_id = var.lxc_storage
    size         = each.value.disk_gb
  }

  # Network interface — NO ip config here, that goes in initialization
  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  initialization {
    hostname = each.key

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
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

  lifecycle {
    ignore_changes = [disk[0].size]
  }
}

# -----------------------------------------------------------------------------
# rship control plane LXC container
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_container" "rship_control" {
  count = var.rship_control != null ? 1 : 0

  description   = "rship control plane"
  node_name     = var.rship_control.node
  tags          = ["linux", "lxc", "rship", "control"]
  started       = true
  start_on_boot = true
  unprivileged  = true

  operating_system {
    template_file_id = var.lxc_template
    type             = "debian"
  }

  cpu {
    cores = var.rship_control.cores
  }

  memory {
    dedicated = var.rship_control.memory_mb
  }

  disk {
    datastore_id = var.lxc_storage
    size         = var.rship_control.disk_gb
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  initialization {
    hostname = "rship-cp-01"

    ip_config {
      ipv4 {
        address = "${var.rship_control.ip}/24"
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

  lifecycle {
    ignore_changes = [disk[0].size]
  }
}
