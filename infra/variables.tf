# -----------------------------------------------------------------------------
# Proxmox connection
# -----------------------------------------------------------------------------

variable "proxmox_endpoint" {
  description = "Proxmox API URL (e.g. https://proxmox-01.local:8006)"
  type        = string
}

variable "proxmox_username" {
  description = "Proxmox API user (e.g. root@pam or terraform@pve)"
  type        = string
}

variable "proxmox_password" {
  description = "Proxmox API password"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Network
# -----------------------------------------------------------------------------

variable "network_bridge" {
  description = "Proxmox bridge for VM/LXC networking"
  type        = string
  default     = "vmbr0"
}

variable "network_gateway" {
  description = "Default gateway"
  type        = string
  default     = "192.168.1.1"
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["192.168.1.1"]
}

# -----------------------------------------------------------------------------
# Templates
# -----------------------------------------------------------------------------

variable "windows_template_id" {
  description = "VM ID of the Windows 11 template (sysprepped with WinRM + unattend.xml)"
  type        = number
  default     = 9000
}

variable "linux_template_id" {
  description = "VM ID of the Linux (Debian/Ubuntu) template"
  type        = number
  default     = 9001
}

variable "lxc_template" {
  description = "LXC container template (e.g. local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst)"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
}

# -----------------------------------------------------------------------------
# SSH
# -----------------------------------------------------------------------------

variable "ssh_public_key" {
  description = "SSH public key for Linux VMs and LXC containers"
  type        = string
}

# -----------------------------------------------------------------------------
# Windows UE nodes
# -----------------------------------------------------------------------------

variable "ue_nodes" {
  description = "UE render/previs nodes"
  type = map(object({
    ip         = string
    node       = string       # Proxmox host
    cores      = number
    memory_mb  = number
    disk_gb    = number
    gpu_pci    = string       # PCI address for GPU passthrough (e.g. 0000:41:00.0)
    rivermax   = bool
    cx6_vf_pci = optional(string, "")  # CX6 SR-IOV VF PCI address (e.g. 0000:0f:00.2) — only when rivermax=true
  }))
}

# -----------------------------------------------------------------------------
# Windows Arnold nodes
# -----------------------------------------------------------------------------

variable "arnold_nodes" {
  description = "Arnold/Fusion render nodes"
  type = map(object({
    ip        = string
    node      = string
    cores     = number
    memory_mb = number
    disk_gb   = number
    gpu_pci   = string
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# Linux VMs
# -----------------------------------------------------------------------------

variable "optik_vm" {
  description = "Optik CV VM config"
  type = object({
    ip        = string
    node      = string
    cores     = number
    memory_mb = number
    disk_gb   = number
    gpu_pci   = string
  })
  default = null
}

variable "control_plane_vm" {
  description = "Ansible control plane VM config"
  type = object({
    ip        = string
    node      = string
    cores     = number
    memory_mb = number
    disk_gb   = number
  })
  default = null
}

# -----------------------------------------------------------------------------
# LXC containers
# -----------------------------------------------------------------------------

variable "rship_nodes" {
  description = "rship worker LXC containers"
  type = map(object({
    ip        = string
    node      = string
    cores     = number
    memory_mb = number
    disk_gb   = number
  }))
  default = {}
}

variable "rship_control" {
  description = "rship control plane LXC container"
  type = object({
    ip        = string
    node      = string
    cores     = number
    memory_mb = number
    disk_gb   = number
  })
  default = null
}

# -----------------------------------------------------------------------------
# Storage
# -----------------------------------------------------------------------------

variable "vm_storage" {
  description = "Proxmox storage pool for VM disks"
  type        = string
  default     = "local-zfs"
}

variable "lxc_storage" {
  description = "Proxmox storage pool for LXC rootfs"
  type        = string
  default     = "local-zfs"
}
