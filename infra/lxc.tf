# -----------------------------------------------------------------------------
# LXC containers — rship, pulse-admin
# -----------------------------------------------------------------------------

locals {
  lxc_containers = merge(
    var.rship_nodes,
    var.pulse_admin_nodes,
  )

  lxc_tags = merge(
    { for k, _ in var.rship_nodes : k => ["linux", "lxc", "rship"] },
    { for k, _ in var.pulse_admin_nodes : k => ["linux", "lxc", "pulse-admin"] },
  )

  lxc_descriptions = merge(
    { for k, _ in var.rship_nodes : k => "rship data worker" },
    { for k, _ in var.pulse_admin_nodes : k => "Control plane / monitoring" },
  )
}

module "lxc" {
  source   = "./modules/proxmox-lxc"
  for_each = local.lxc_containers

  id               = each.value.id
  hostname         = each.key
  description      = local.lxc_descriptions[each.key]
  node_name        = each.value.node
  tags             = local.lxc_tags[each.key]
  template_file_id = var.lxc_template
  cores            = each.value.cores
  memory_mb        = each.value.memory_mb
  disk_gb          = each.value.disk_gb
  datastore_id     = var.proxmox_hosts[each.value.node].storage_id
  network_bridge   = var.network_bridge
  ip               = each.value.ip
  gateway          = var.network_gateway
  dns_servers      = var.dns_servers
  ssh_keys         = [var.ssh_public_key]
}
