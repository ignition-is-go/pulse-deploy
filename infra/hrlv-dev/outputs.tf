# =============================================================================
# Outputs — summary view after apply
# =============================================================================

output "vm_summary" {
  description = "VM count per group"
  value = {
    ue_content    = length(var.ue_content)
    ue_editing    = length(var.ue_editing)
    ue_previs     = length(var.ue_previs)
    ue_staging    = length(var.ue_staging)
    ue_plugindev = length(var.ue_plugindev)
    ue_runner     = length(var.ue_runner)
    touch         = length(var.touch)
    arnold_fusion = length(var.arnold_fusion)
    workstation   = length(var.workstation)
    optik         = length(var.optik)
    rship         = length(var.rship)
    pixelfarm     = length(var.pixelfarm)
    pulse_admin   = length(var.pulse_admin)
    rustdesk      = length(var.rustdesk)
    proxmox       = length([for k, v in var.proxmox_hosts : k if v.ip != "" && v.cores > 0])
  }
}
