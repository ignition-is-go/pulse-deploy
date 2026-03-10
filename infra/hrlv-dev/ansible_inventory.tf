# =============================================================================
# Ansible inventory — ansible/ansible provider resources
#
# These resources are read by the cloud.terraform.terraform_provider inventory
# plugin, eliminating the need for a manual hosts.yml file.
# =============================================================================

# -----------------------------------------------------------------------------
# Groups — hierarchy + connection vars
# -----------------------------------------------------------------------------

resource "ansible_group" "windows" {
  name = "windows"
  children = [
    "ue",
    "touch",
    "arnold_fusion",
    "workstation",
  ]
  variables = {
    ansible_connection                   = "winrm"
    ansible_winrm_transport              = "ntlm"
    ansible_winrm_server_cert_validation = "ignore"
    ansible_port                         = "5985"
  }
}

resource "ansible_group" "ue" {
  name = "ue"
  children = [
    "ue_content",
    "ue_editing",
    "ue_previs",
    "ue_staging",
    "ue_plugin_dev",
    "ue_runner",
    "workstation",
  ]
}

resource "ansible_group" "linux" {
  name = "linux"
  children = [
    "proxmox",
    "optik",
    "pbs",
    "pixelfarm",
    "rship",
    "rustdesk",
    "pulse_admin",
  ]
  variables = {
    ansible_connection = "ssh"
  }
}

# --- Windows sub-groups ------------------------------------------------------

resource "ansible_group" "ue_content" {
  name     = "ue_content"
  children = ["ue_content_group_01", "ue_content_group_02"]
}

resource "ansible_group" "ue_content_group_01" {
  name = "ue_content_group_01"
}

resource "ansible_group" "ue_content_group_02" {
  name = "ue_content_group_02"
}

resource "ansible_group" "ue_editing" {
  name = "ue_editing"
}

resource "ansible_group" "ue_previs" {
  name = "ue_previs"
}

resource "ansible_group" "ue_staging" {
  name = "ue_staging"
}

resource "ansible_group" "ue_plugin_dev" {
  name = "ue_plugin_dev"
}

resource "ansible_group" "ue_runner" {
  name = "ue_runner"
}

resource "ansible_group" "touch" {
  name = "touch"
}

resource "ansible_group" "arnold_fusion" {
  name = "arnold_fusion"
}

resource "ansible_group" "workstation" {
  name = "workstation"
}

# --- Linux sub-groups --------------------------------------------------------

resource "ansible_group" "optik" {
  name = "optik"
}

resource "ansible_group" "pixelfarm" {
  name = "pixelfarm"
}

resource "ansible_group" "rship" {
  name = "rship"
}

resource "ansible_group" "rustdesk" {
  name = "rustdesk"
}

resource "ansible_group" "pbs" {
  name = "pbs"
}

resource "ansible_group" "pulse_admin" {
  name = "pulse_admin"
}

# -----------------------------------------------------------------------------
# Hosts — one ansible_host per VM/LXC, grouped automatically
# -----------------------------------------------------------------------------

# --- Windows GPU VMs ---------------------------------------------------------

locals {
  ue_content_group_01 = { for k, v in var.ue_content : k => v if v.node == "nyc-prod-pve-01" }
  ue_content_group_02 = { for k, v in var.ue_content : k => v if v.node == "nyc-prod-pve-02" }
}

resource "ansible_host" "ue_content_group_01" {
  for_each = local.ue_content_group_01
  name     = each.key
  groups   = ["ue_content_group_01"]
  variables = merge(
    {
      ansible_host      = each.value.ip
      ip_2110           = each.value.ip_2110
      ndisplay_node     = each.value.ndisplay_node
      concert_server_ip = var.ue_editing["ue-editing-02"].ip
    },
    each.value.ndisplay_primary == true ? { ndisplay_primary = "true" } : {},
    each.value.ip_smb != null ? { ip_smb = each.value.ip_smb } : {},
    contains(keys(local.vm_mac_2110), each.key) ? { mac_2110 = local.vm_mac_2110[each.key] } : {},
    contains(keys(local.vm_mac_smb), each.key) ? { mac_smb = local.vm_mac_smb[each.key] } : {},
  )
}

resource "ansible_host" "ue_content_group_02" {
  for_each = local.ue_content_group_02
  name     = each.key
  groups   = ["ue_content_group_02"]
  variables = merge(
    {
      ansible_host      = each.value.ip
      ip_2110           = each.value.ip_2110
      ndisplay_node     = each.value.ndisplay_node
      concert_server_ip = var.ue_editing["ue-editing-02"].ip
    },
    each.value.ndisplay_primary == true ? { ndisplay_primary = "true" } : {},
    each.value.ip_smb != null ? { ip_smb = each.value.ip_smb } : {},
    contains(keys(local.vm_mac_2110), each.key) ? { mac_2110 = local.vm_mac_2110[each.key] } : {},
    contains(keys(local.vm_mac_smb), each.key) ? { mac_smb = local.vm_mac_smb[each.key] } : {},
  )
}

resource "ansible_host" "ue_editing" {
  for_each = var.ue_editing
  name     = each.key
  groups   = ["ue_editing"]
  variables = merge(
    {
      ansible_host      = each.value.ip
      concert_server_ip = each.value.ip
    },
    each.value.ip_2110 != null ? { ip_2110 = each.value.ip_2110 } : {},
    each.value.ip_smb != null ? { ip_smb = each.value.ip_smb } : {},
    contains(keys(local.vm_mac_2110), each.key) ? { mac_2110 = local.vm_mac_2110[each.key] } : {},
    contains(keys(local.vm_mac_smb), each.key) ? { mac_smb = local.vm_mac_smb[each.key] } : {},
  )
}

resource "ansible_host" "ue_previs" {
  for_each = var.ue_previs
  name     = each.key
  groups   = ["ue_previs"]
  variables = merge(
    {
      ansible_host = each.value.ip
      ip_2110    = each.value.ip_2110
    },
    each.value.ip_smb != null ? { ip_smb = each.value.ip_smb } : {},
    contains(keys(local.vm_mac_2110), each.key) ? { mac_2110 = local.vm_mac_2110[each.key] } : {},
    contains(keys(local.vm_mac_smb), each.key) ? { mac_smb = local.vm_mac_smb[each.key] } : {},
  )
}

resource "ansible_host" "touch" {
  for_each = var.touch
  name     = each.key
  groups   = ["touch"]
  variables = merge(
    { ansible_host = each.value.ip },
    each.value.ip_2110 != null ? { ip_2110 = each.value.ip_2110 } : {},
    each.value.ip_smb != null ? { ip_smb = each.value.ip_smb } : {},
    contains(keys(local.vm_mac_2110), each.key) ? { mac_2110 = local.vm_mac_2110[each.key] } : {},
    contains(keys(local.vm_mac_smb), each.key) ? { mac_smb = local.vm_mac_smb[each.key] } : {},
  )
}

resource "ansible_host" "arnold_fusion" {
  for_each = var.arnold_fusion
  name     = each.key
  groups   = ["arnold_fusion"]
  variables = merge(
    { ansible_host = each.value.ip },
    each.value.ip_2110 != null ? { ip_2110 = each.value.ip_2110 } : {},
    each.value.ip_smb != null ? { ip_smb = each.value.ip_smb } : {},
    contains(keys(local.vm_mac_2110), each.key) ? { mac_2110 = local.vm_mac_2110[each.key] } : {},
    contains(keys(local.vm_mac_smb), each.key) ? { mac_smb = local.vm_mac_smb[each.key] } : {},
  )
}

resource "ansible_host" "workstation" {
  for_each = var.workstation
  name     = each.key
  groups   = ["workstation"]
  variables = merge(
    { ansible_host = each.value.ip },
    each.value.ip_2110 != null ? { ip_2110 = each.value.ip_2110 } : {},
    each.value.ip_smb != null ? { ip_smb = each.value.ip_smb } : {},
    contains(keys(local.vm_mac_2110), each.key) ? { mac_2110 = local.vm_mac_2110[each.key] } : {},
    contains(keys(local.vm_mac_smb), each.key) ? { mac_smb = local.vm_mac_smb[each.key] } : {},
  )
}

# --- Windows VMs (no GPU) ---------------------------------------------------

resource "ansible_host" "ue_staging" {
  for_each = var.ue_staging
  name     = each.key
  groups   = ["ue_staging"]
  variables = merge(
    { ansible_host = each.value.ip },
    each.value.ip_smb != null ? { ip_smb = each.value.ip_smb } : {},
    contains(keys(local.vm_mac_smb), each.key) ? { mac_smb = local.vm_mac_smb[each.key] } : {},
  )
}

resource "ansible_host" "ue_plugin_dev" {
  for_each = var.ue_plugin_dev
  name     = each.key
  groups   = ["ue_plugin_dev"]
  variables = merge(
    { ansible_host = each.value.ip },
    each.value.ip_2110 != null ? { ip_2110 = each.value.ip_2110 } : {},
    each.value.ip_smb != null ? { ip_smb = each.value.ip_smb } : {},
    contains(keys(local.vm_mac_2110), each.key) ? { mac_2110 = local.vm_mac_2110[each.key] } : {},
    contains(keys(local.vm_mac_smb), each.key) ? { mac_smb = local.vm_mac_smb[each.key] } : {},
  )
}

resource "ansible_host" "ue_runner" {
  for_each = var.ue_runner
  name     = each.key
  groups   = ["ue_runner"]
  variables = {
    ansible_host = each.value.ip
  }
}

# --- Linux GPU VMs -----------------------------------------------------------

resource "ansible_host" "optik" {
  for_each = var.optik
  name     = each.key
  groups   = ["optik"]
  variables = {
    ansible_host = each.value.ip
  }
}

# --- LXC containers ----------------------------------------------------------

resource "ansible_host" "rship" {
  for_each = var.rship
  name     = each.key
  groups   = ["rship"]
  variables = {
    ansible_host = each.value.ip
  }
}

resource "ansible_host" "pbs" {
  for_each = var.pbs
  name     = each.key
  groups   = ["pbs"]
  variables = {
    ansible_host = each.value.ip
  }
}

resource "ansible_host" "pulse_admin" {
  for_each = var.pulse_admin
  name     = each.key
  groups   = ["pulse_admin"]
  variables = {
    ansible_host = each.value.ip
  }
}

resource "ansible_host" "pixelfarm" {
  for_each = var.pixelfarm
  name     = each.key
  groups   = ["pixelfarm"]
  variables = {
    ansible_host = each.value.ip
  }
}

resource "ansible_host" "rustdesk" {
  for_each = var.rustdesk
  name     = each.key
  groups   = ["rustdesk"]
  variables = {
    ansible_host = each.value.ip
  }
}

# --- Proxmox hypervisor groups ------------------------------------------------

resource "ansible_group" "proxmox" {
  name     = "proxmox"
  children = ["proxmox_prod", "proxmox_dev"]
  variables = {
    ansible_user = "root"
  }
}

resource "ansible_group" "proxmox_prod" {
  name = "proxmox_prod"
}

resource "ansible_group" "proxmox_dev" {
  name = "proxmox_dev"
}

# --- Proxmox hosts (physical hypervisors) -------------------------------------

resource "ansible_host" "proxmox_prod" {
  for_each = {
    for k, v in var.proxmox_hosts : k => v
    if startswith(k, "nyc-prod-") && v.ip != "" && v.cores > 0
  }
  name   = each.key
  groups = ["proxmox_prod"]
  variables = merge(
    { ansible_host = each.value.ip },
    length(each.value.sriov_cards) > 0 ? { sriov_cards_json = jsonencode(each.value.sriov_cards) } : {},
    length(each.value.gpus) > 0 ? { gpus_json = jsonencode(each.value.gpus) } : {},
    length(local.vf_macs_by_host[each.key]) > 0 ? { vf_macs_json = jsonencode(local.vf_macs_by_host[each.key]) } : {},
  )
}

resource "ansible_host" "proxmox_dev" {
  for_each = {
    for k, v in var.proxmox_hosts : k => v
    if startswith(k, "nyc-dev-") && v.ip != "" && v.cores > 0
  }
  name   = each.key
  groups = ["proxmox_dev"]
  variables = merge(
    { ansible_host = each.value.ip },
    length(each.value.sriov_cards) > 0 ? { sriov_cards_json = jsonencode(each.value.sriov_cards) } : {},
    length(each.value.gpus) > 0 ? { gpus_json = jsonencode(each.value.gpus) } : {},
    length(local.vf_macs_by_host[each.key]) > 0 ? { vf_macs_json = jsonencode(local.vf_macs_by_host[each.key]) } : {},
  )
}
