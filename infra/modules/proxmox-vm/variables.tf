# =============================================================================
# proxmox-vm module — input variables
# =============================================================================

# --- Identity ----------------------------------------------------------------

variable "name" {
  description = "VM name (Proxmox display name)"
  type        = string
}

variable "node_name" {
  description = "Proxmox cluster node to place this VM on"
  type        = string
}

variable "tags" {
  description = "Tags applied to the VM in Proxmox"
  type        = list(string)
  default     = []
}

# --- Clone source ------------------------------------------------------------

variable "template_id" {
  description = "VM ID of the template to clone from"
  type        = number
}

# --- Compute -----------------------------------------------------------------

variable "cores" {
  description = "Number of CPU cores"
  type        = number
}

variable "memory_mb" {
  description = "Dedicated memory in MB"
  type        = number
}

# --- Storage -----------------------------------------------------------------

variable "disk_gb" {
  description = "OS disk size in GB"
  type        = number
}

variable "datastore_id" {
  description = "Proxmox storage pool for VM disks and EFI disk"
  type        = string
  default     = "local-zfs"
}

# --- Network -----------------------------------------------------------------

variable "network_bridge" {
  description = "Proxmox bridge for the VM NIC"
  type        = string
  default     = "vmbr0"
}

# --- Operating system ---------------------------------------------------------

variable "os_type" {
  description = "Proxmox OS type hint (e.g. 'win11', 'l26')"
  type        = string
  default     = "l26"
}

# --- PCI passthrough ----------------------------------------------------------

variable "pci_devices" {
  description = <<-EOT
    List of PCI devices to pass through. Each entry creates a hostpci block.
    Use EITHER 'id' (raw PCI address) OR 'mapping' (Proxmox resource mapping name).
    When non-empty, the module automatically sets q35/OVMF/host CPU.
  EOT
  type = list(object({
    device  = string
    id      = optional(string, "")
    mapping = optional(string, "")
    pcie    = optional(bool, true)
    rombar  = optional(bool, true)
    xvga    = optional(bool, false)
  }))
  default = []

  validation {
    condition = alltrue([
      for d in var.pci_devices : (d.id != "" || d.mapping != "") && !(d.id != "" && d.mapping != "")
    ])
    error_message = "Each pci_device must specify exactly one of 'id' or 'mapping', not both."
  }
}

# --- Cloud-init (optional) ----------------------------------------------------

variable "cloud_init" {
  description = <<-EOT
    Cloud-init config. null = no initialization block.
    ssh_keys empty = no user_account block (Windows).
    ssh_keys populated = user_account with keys (Linux).
  EOT
  type = object({
    ip       = string
    gateway  = string
    dns      = list(string)
    ssh_keys = optional(list(string), [])
  })
  default = null
}

# --- Boot behavior ------------------------------------------------------------

variable "started" {
  description = "Start VM after creation"
  type        = bool
  default     = true
}

variable "on_boot" {
  description = "Start VM when Proxmox host boots"
  type        = bool
  default     = true
}

# --- Overrides ----------------------------------------------------------------

variable "override_bios" {
  description = "Force bios type. null = auto-detect from pci_devices"
  type        = string
  default     = null

  validation {
    condition     = var.override_bios == null || contains(["ovmf", "seabios"], var.override_bios)
    error_message = "override_bios must be null, 'ovmf', or 'seabios'."
  }
}

variable "override_cpu_type" {
  description = "Force CPU type. null = auto-detect ('host' if PCI, 'x86-64-v2-AES' if none)"
  type        = string
  default     = null
}
