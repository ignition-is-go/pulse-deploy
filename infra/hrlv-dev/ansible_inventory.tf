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
    "ue_previs",
    "ue_staging",
    "ue_build",
  ]
}

resource "ansible_group" "linux" {
  name = "linux"
  children = [
    "optik",
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
  name = "ue_content"
}

resource "ansible_group" "ue_previs" {
  name = "ue_previs"
}

resource "ansible_group" "ue_staging" {
  name = "ue_staging"
}

resource "ansible_group" "ue_build" {
  name = "ue_build"
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

resource "ansible_group" "pulse_admin" {
  name = "pulse_admin"
}

# -----------------------------------------------------------------------------
# Hosts — one ansible_host per VM/LXC, grouped automatically
# -----------------------------------------------------------------------------

# --- Windows GPU VMs ---------------------------------------------------------

resource "ansible_host" "ue_content" {
  for_each = var.ue_content
  name     = each.key
  groups   = ["ue_content"]
  variables = {
    ansible_host = each.value.ip
  }
}

resource "ansible_host" "ue_previs" {
  for_each = var.ue_previs
  name     = each.key
  groups   = ["ue_previs"]
  variables = {
    ansible_host = each.value.ip
  }
}

resource "ansible_host" "touch" {
  for_each = var.touch
  name     = each.key
  groups   = ["touch"]
  variables = {
    ansible_host = each.value.ip
  }
}

resource "ansible_host" "arnold_fusion" {
  for_each = var.arnold_fusion
  name     = each.key
  groups   = ["arnold_fusion"]
  variables = {
    ansible_host = each.value.ip
  }
}

resource "ansible_host" "workstation" {
  for_each = var.workstation
  name     = each.key
  groups   = ["workstation"]
  variables = {
    ansible_host = each.value.ip
  }
}

# --- Windows VMs (no GPU) ---------------------------------------------------

resource "ansible_host" "ue_staging" {
  for_each = var.ue_staging
  name     = each.key
  groups   = ["ue_staging"]
  variables = {
    ansible_host = each.value.ip
  }
}

resource "ansible_host" "ue_build" {
  for_each = var.ue_build
  name     = each.key
  groups   = ["ue_build"]
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
