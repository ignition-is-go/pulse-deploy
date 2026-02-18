# =============================================================================
# Outputs — per-type for Ansible inventory mapping
# =============================================================================

# --- Windows GPU VMs ---------------------------------------------------------

output "ue_render_nodes" {
  description = "UE nDisplay render nodes"
  value = { for k, v in var.ue_render_nodes : k => {
    id = v.id
    ip = v.ip
  } }
}

output "touch_nodes" {
  description = "TouchDesigner nodes"
  value = { for k, v in var.touch_nodes : k => {
    id = v.id
    ip = v.ip
  } }
}

output "arnold_nodes" {
  description = "Arnold/Fusion render nodes"
  value = { for k, v in var.arnold_nodes : k => {
    id = v.id
    ip = v.ip
  } }
}

output "workstations" {
  description = "Artist workstations"
  value = { for k, v in var.workstations : k => {
    id = v.id
    ip = v.ip
  } }
}

# --- Windows VMs (no GPU) ---------------------------------------------------

output "ue_build_nodes" {
  description = "UE build nodes"
  value = { for k, v in var.ue_build_nodes : k => {
    id = v.id
    ip = v.ip
  } }
}

output "ue_staging_nodes" {
  description = "UE staging / distribution nodes"
  value = { for k, v in var.ue_staging_nodes : k => {
    id = v.id
    ip = v.ip
  } }
}

output "pixelfarm_nodes" {
  description = "Pixel Farm nodes"
  value = { for k, v in var.pixelfarm_nodes : k => {
    id = v.id
    ip = v.ip
  } }
}

# --- Linux GPU VMs -----------------------------------------------------------

output "optik_nodes" {
  description = "Optik computer vision nodes"
  value = { for k, v in var.optik_nodes : k => {
    id = v.id
    ip = v.ip
  } }
}

# --- LXC containers ----------------------------------------------------------

output "rship_nodes" {
  description = "rship data workers"
  value = { for k, v in var.rship_nodes : k => {
    id = v.id
    ip = v.ip
  } }
}

output "pulse_admin_nodes" {
  description = "Control plane nodes"
  value = { for k, v in var.pulse_admin_nodes : k => {
    id = v.id
    ip = v.ip
  } }
}
