# -----------------------------------------------------------------------------
# Proxmox connection
# -----------------------------------------------------------------------------

variable "proxmox_endpoint" {
  description = "Proxmox API URL (e.g. https://nyc-prod-pve-01.local:8006)"
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
# Proxmox hosts — physical hardware inventory
# -----------------------------------------------------------------------------

variable "proxmox_hosts" {
  description = "Physical Proxmox hosts and their hardware resources"
  type = map(object({
    cores      = number       # total physical cores
    memory_gb  = number       # total RAM in GB
    storage_gb = number       # total usable storage in GB
    storage_id = string       # Proxmox storage pool name (e.g. zfs-nvme-01)
    gpus       = list(string) # GPU PCI addresses in slot order
    cx6_vfs    = list(string) # CX6 SR-IOV VF PCI addresses in slot order
  }))
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

variable "windows_template_ids" {
  description = "Windows cloudbase-init template VM ID per Proxmox node (keyed by node name)"
  type        = map(number)
}

variable "linux_template_id" {
  description = "VM ID of the Linux (Debian/Ubuntu) cloud-init template"
  type        = number
}

variable "lxc_template" {
  description = "LXC container template (e.g. local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst)"
  type        = string
}

# -----------------------------------------------------------------------------
# SSH
# -----------------------------------------------------------------------------

variable "ssh_public_key" {
  description = "SSH public key for Linux VMs and LXC containers"
  type        = string
}

variable "windows_admin_password" {
  description = "Administrator password for Windows VMs (set via cloudbase-init)"
  type        = string
  sensitive   = true
}

# =============================================================================
# Windows GPU VMs
# =============================================================================

variable "ue_content" {
  description = "UE nDisplay content render nodes (Windows + GPU)"
  type = map(object({
    id        = number
    ip        = string
    node      = string # key into proxmox_hosts
    cores     = number
    memory_mb = number
    disk_gb   = number
    gpu_slots = list(number)     # indices into proxmox_hosts[node].gpus
    cx6_slot  = optional(number) # index into proxmox_hosts[node].cx6_vfs
  }))
  default = {}
}

variable "ue_previs" {
  description = "UE nDisplay previs render nodes (Windows + GPU)"
  type = map(object({
    id        = number
    ip        = string
    node      = string
    cores     = number
    memory_mb = number
    disk_gb   = number
    gpu_slots = list(number)
    cx6_slot  = optional(number)
  }))
  default = {}
}

variable "touch" {
  description = "TouchDesigner nodes — volumetric content render (Windows + GPU)"
  type = map(object({
    id        = number
    ip        = string
    node      = string
    cores     = number
    memory_mb = number
    disk_gb   = number
    gpu_slots = list(number)
    cx6_slot  = optional(number)
  }))
  default = {}
}

variable "arnold_fusion" {
  description = "Arnold/Fusion offline render + compositing nodes (Windows + GPU)"
  type = map(object({
    id        = number
    ip        = string
    node      = string
    cores     = number
    memory_mb = number
    disk_gb   = number
    gpu_slots = list(number)
    cx6_slot  = optional(number)
  }))
  default = {}
}

variable "workstation" {
  description = "Artist workstations — content creation, RDP (Windows + GPU)"
  type = map(object({
    id        = number
    ip        = string
    node      = string
    cores     = number
    memory_mb = number
    disk_gb   = number
    gpu_slots = list(number)
    cx6_slot  = optional(number)
  }))
  default = {}
}

# =============================================================================
# Windows VMs (no GPU)
# =============================================================================

variable "ue_build" {
  description = "UE cook/package build nodes (Windows, headless)"
  type = map(object({
    id        = number
    ip        = string
    node      = string
    cores     = number
    memory_mb = number
    disk_gb   = number
    cx6_slot  = optional(number)
  }))
  default = {}
}

variable "ue_staging" {
  description = "Plastic sync + build distribution nodes (Windows)"
  type = map(object({
    id        = number
    ip        = string
    node      = string
    cores     = number
    memory_mb = number
    disk_gb   = number
    cx6_slot  = optional(number)
  }))
  default = {}
}

# =============================================================================
# Linux GPU VMs
# =============================================================================

variable "optik" {
  description = "Optik computer vision nodes (Linux + GPU, can consume all GPUs on a host)"
  type = map(object({
    id        = number
    ip        = string
    node      = string
    cores     = number
    memory_mb = number
    disk_gb   = number
    gpu_slots = list(number)
    cx6_slot  = optional(number)
  }))
  default = {}
}

# =============================================================================
# LXC containers
# =============================================================================

variable "rship" {
  description = "rship real-time data workers (LXC)"
  type = map(object({
    id        = number
    ip        = string
    node      = string
    cores     = number
    memory_mb = number
    disk_gb   = number
  }))
  default = {}
}

variable "pulse_admin" {
  description = "Control plane — Ansible, monitoring (LXC)"
  type = map(object({
    id        = number
    ip        = string
    node      = string
    cores     = number
    memory_mb = number
    disk_gb   = number
  }))
  default = {}
}

variable "pixelfarm" {
  description = "Pixel Farm render job orchestration (LXC)"
  type = map(object({
    id        = number
    ip        = string
    node      = string
    cores     = number
    memory_mb = number
    disk_gb   = number
  }))
  default = {}
}

variable "rustdesk" {
  description = "RustDesk remote desktop server (LXC)"
  type = map(object({
    id        = number
    ip        = string
    node      = string
    cores     = number
    memory_mb = number
    disk_gb   = number
  }))
  default = {}
}
