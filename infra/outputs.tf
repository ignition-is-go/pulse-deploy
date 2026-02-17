# =============================================================================
# Outputs — per-type for Ansible inventory mapping
# =============================================================================

# --- Windows GPU VMs ---------------------------------------------------------

output "ue_render_nodes" {
  description = "UE nDisplay render nodes"
  value = { for k, v in var.ue_render_nodes : k => {
    ip    = v.ip
    vm_id = module.windows_gpu_vm[k].vm_id
  }}
}

output "touch_nodes" {
  description = "TouchDesigner nodes"
  value = { for k, v in var.touch_nodes : k => {
    ip    = v.ip
    vm_id = module.windows_gpu_vm[k].vm_id
  }}
}

output "arnold_nodes" {
  description = "Arnold/Fusion render nodes"
  value = { for k, v in var.arnold_nodes : k => {
    ip    = v.ip
    vm_id = module.windows_gpu_vm[k].vm_id
  }}
}

output "workstations" {
  description = "Artist workstations"
  value = { for k, v in var.workstations : k => {
    ip    = v.ip
    vm_id = module.windows_gpu_vm[k].vm_id
  }}
}

# --- Windows VMs (no GPU) ---------------------------------------------------

output "ue_build_nodes" {
  description = "UE build nodes"
  value = { for k, v in var.ue_build_nodes : k => {
    ip    = v.ip
    vm_id = module.windows_vm[k].vm_id
  }}
}

output "ue_staging_nodes" {
  description = "UE staging / distribution nodes"
  value = { for k, v in var.ue_staging_nodes : k => {
    ip    = v.ip
    vm_id = module.windows_vm[k].vm_id
  }}
}

output "pixelfarm_nodes" {
  description = "Pixel Farm nodes"
  value = { for k, v in var.pixelfarm_nodes : k => {
    ip    = v.ip
    vm_id = module.windows_vm[k].vm_id
  }}
}

output "runner_win_nodes" {
  description = "Windows CI/CD runners"
  value = { for k, v in var.runner_win_nodes : k => {
    ip    = v.ip
    vm_id = module.windows_vm[k].vm_id
  }}
}

# --- Linux GPU VMs -----------------------------------------------------------

output "optik_nodes" {
  description = "Optik computer vision nodes"
  value = { for k, v in var.optik_nodes : k => {
    ip    = v.ip
    vm_id = module.linux_gpu_vm[k].vm_id
  }}
}

# --- LXC containers ----------------------------------------------------------

output "runner_lxc_nodes" {
  description = "Linux CI/CD runners"
  value = { for k, v in var.runner_lxc_nodes : k => {
    ip           = v.ip
    container_id = module.lxc[k].container_id
  }}
}

output "rship_nodes" {
  description = "rship data workers"
  value = { for k, v in var.rship_nodes : k => {
    ip           = v.ip
    container_id = module.lxc[k].container_id
  }}
}

output "gitlab_nodes" {
  description = "GitLab instances"
  value = { for k, v in var.gitlab_nodes : k => {
    ip           = v.ip
    container_id = module.lxc[k].container_id
  }}
}

output "pulse_admin_nodes" {
  description = "Control plane nodes"
  value = { for k, v in var.pulse_admin_nodes : k => {
    ip           = v.ip
    container_id = module.lxc[k].container_id
  }}
}

# --- Ansible inventory snippet -----------------------------------------------

output "ansible_inventory_snippet" {
  description = "Paste into inventories/hrlv/hosts.yml or use as reference"
  value = templatefile("${path.module}/templates/ansible-inventory.tpl", {
    ue_render_nodes   = var.ue_render_nodes
    touch_nodes       = var.touch_nodes
    arnold_nodes      = var.arnold_nodes
    workstations      = var.workstations
    ue_build_nodes    = var.ue_build_nodes
    ue_staging_nodes  = var.ue_staging_nodes
    pixelfarm_nodes   = var.pixelfarm_nodes
    runner_win_nodes  = var.runner_win_nodes
    optik_nodes       = var.optik_nodes
    runner_lxc_nodes  = var.runner_lxc_nodes
    rship_nodes       = var.rship_nodes
    gitlab_nodes      = var.gitlab_nodes
    pulse_admin_nodes = var.pulse_admin_nodes
  })
}
