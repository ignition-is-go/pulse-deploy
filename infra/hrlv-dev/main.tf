terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.95.0"
    }
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.3"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint

  # PCI passthrough (hostpci) requires root@pam auth — API tokens won't work
  username = var.proxmox_username
  password = var.proxmox_password

  insecure = true

  ssh {
    agent = true
  }
}

# -----------------------------------------------------------------------------
# Hostname length guard — Windows NetBIOS limit is 15 characters.
# Cloudbase-init's SetHostNamePlugin silently truncates longer names, causing
# the actual hostname to diverge from the Terraform/Ansible inventory name.
# -----------------------------------------------------------------------------

locals {
  all_hostnames = concat(
    keys(var.ue_content),
    keys(var.ue_editing),
    keys(var.ue_previs),
    keys(var.touch),
    keys(var.arnold_fusion),
    keys(var.workstation),
    keys(var.ue_plugin_dev),
    keys(var.ue_runner),
    keys(var.ue_staging),
    keys(var.optik),
    keys(var.rship),
    keys(var.pulse_admin),
    keys(var.pixelfarm),
    keys(var.rustdesk),
  )
  oversized_hostnames = [for n in local.all_hostnames : "${n} (${length(n)})" if length(n) > 15]
}

resource "terraform_data" "hostname_length_check" {
  lifecycle {
    precondition {
      condition     = length(local.oversized_hostnames) == 0
      error_message = "Hostnames exceed 15 chars and will be silently truncated by Windows: ${join(", ", local.oversized_hostnames)}"
    }
  }
}
