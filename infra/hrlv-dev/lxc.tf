# -----------------------------------------------------------------------------
# LXC containers — rship, pulse_admin, pixelfarm, rustdesk
# -----------------------------------------------------------------------------

locals {
  lxc_containers = merge(
    var.rship,
    var.pulse_admin,
    var.pixelfarm,
    var.rustdesk,
  )

  lxc_tags = merge(
    { for k, _ in var.rship : k => ["linux", "lxc", "rship"] },
    { for k, _ in var.pulse_admin : k => ["linux", "lxc", "pulse-admin"] },
    { for k, _ in var.pixelfarm : k => ["linux", "lxc", "pixelfarm"] },
    { for k, _ in var.rustdesk : k => ["linux", "lxc", "rustdesk"] },
  )

  lxc_descriptions = merge(
    { for k, _ in var.rship : k => "rship data worker" },
    { for k, _ in var.pulse_admin : k => "Control plane / monitoring" },
    { for k, _ in var.pixelfarm : k => "Pixel Farm render orchestration" },
    { for k, _ in var.rustdesk : k => "RustDesk remote desktop server" },
  )
}

module "lxc" {
  source   = "../modules/proxmox-lxc"
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
