# =============================================================================
# Outputs — per-type for Ansible inventory mapping
# =============================================================================

# --- Proxmox hosts -----------------------------------------------------------

output "proxmox_hosts" {
  description = "Physical Proxmox hypervisors"
  value = { for k, v in var.proxmox_hosts : k => {
    ip   = v.ip
    gpus = length(v.gpus)
    vfs  = length(v.cx6_vfs)
    sriov = [for c in v.sriov_cards : "${c.type} ${join(",", c.pci_slots)}"]
  } if v.ip != "" && v.cores > 0 }
}

# --- Windows GPU VMs ---------------------------------------------------------

output "ue_content" {
  description = "UE nDisplay content render nodes"
  value = { for k, v in var.ue_content : k => {
    id               = v.id
    ip               = v.ip
    media_ip         = v.media_ip
    ndisplay_node    = v.ndisplay_node
    ndisplay_primary = v.ndisplay_primary
  } }
}

output "ue_previs" {
  description = "UE nDisplay previs render nodes"
  value = { for k, v in var.ue_previs : k => {
    id       = v.id
    ip       = v.ip
    media_ip = v.media_ip
  } }
}

output "touch" {
  description = "TouchDesigner nodes"
  value = { for k, v in var.touch : k => {
    id = v.id
    ip = v.ip
  } }
}

output "arnold_fusion" {
  description = "Arnold/Fusion render nodes"
  value = { for k, v in var.arnold_fusion : k => {
    id = v.id
    ip = v.ip
  } }
}

output "workstation" {
  description = "Artist workstations"
  value = { for k, v in var.workstation : k => {
    id = v.id
    ip = v.ip
  } }
}

# --- Windows VMs (no GPU) ---------------------------------------------------

output "ue_plugin_dev" {
  description = "UE plugin development nodes"
  value = { for k, v in var.ue_plugin_dev : k => {
    id = v.id
    ip = v.ip
  } }
}

output "ue_runner" {
  description = "Headless UE automation runners"
  value = { for k, v in var.ue_runner : k => {
    id = v.id
    ip = v.ip
  } }
}

output "ue_staging" {
  description = "UE staging / distribution nodes"
  value = { for k, v in var.ue_staging : k => {
    id = v.id
    ip = v.ip
  } }
}

# --- Linux GPU VMs -----------------------------------------------------------

output "optik" {
  description = "Optik computer vision nodes"
  value = { for k, v in var.optik : k => {
    id = v.id
    ip = v.ip
  } }
}

# --- LXC containers ----------------------------------------------------------

output "rship" {
  description = "rship data workers"
  value = { for k, v in var.rship : k => {
    id = v.id
    ip = v.ip
  } }
}

output "pulse_admin" {
  description = "Control plane nodes"
  value = { for k, v in var.pulse_admin : k => {
    id = v.id
    ip = v.ip
  } }
}

output "pixelfarm" {
  description = "Pixel Farm nodes"
  value = { for k, v in var.pixelfarm : k => {
    id = v.id
    ip = v.ip
  } }
}

output "rustdesk" {
  description = "RustDesk server"
  value = { for k, v in var.rustdesk : k => {
    id = v.id
    ip = v.ip
  } }
}
