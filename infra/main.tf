terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.95.0"
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
