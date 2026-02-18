# =============================================================================
# proxmox-lxc module — input variables
# =============================================================================

variable "id" {
  description = "Proxmox ID"
  type        = number
}

variable "hostname" {
  description = "Container hostname"
  type        = string
}

variable "description" {
  description = "Container description"
  type        = string
  default     = ""
}

variable "node_name" {
  description = "Proxmox cluster node"
  type        = string
}

variable "tags" {
  description = "Tags"
  type        = list(string)
  default     = []
}

# --- Template -----------------------------------------------------------------

variable "template_file_id" {
  description = "LXC template (e.g. local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst)"
  type        = string
}

variable "os_type" {
  description = "LXC OS type (e.g. 'debian', 'ubuntu')"
  type        = string
  default     = "debian"
}

# --- Compute ------------------------------------------------------------------

variable "cores" {
  description = "Number of CPU cores"
  type        = number
}

variable "memory_mb" {
  description = "Dedicated memory in MB"
  type        = number
}

# --- Storage ------------------------------------------------------------------

variable "disk_gb" {
  description = "Root filesystem size in GB"
  type        = number
}

variable "datastore_id" {
  description = "Proxmox storage pool for LXC rootfs"
  type        = string
}

# --- Network ------------------------------------------------------------------

variable "network_bridge" {
  description = "Proxmox bridge"
  type        = string
  default     = "vmbr0"
}

variable "ip" {
  description = "Static IPv4 address (without CIDR suffix)"
  type        = string
}

variable "gateway" {
  description = "Default gateway"
  type        = string
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
}

# --- SSH ----------------------------------------------------------------------

variable "ssh_keys" {
  description = "SSH public keys"
  type        = list(string)
}

# --- Boot behavior ------------------------------------------------------------

variable "started" {
  type    = bool
  default = true
}

variable "start_on_boot" {
  description = "Start container when Proxmox host boots — false prevents boot loops if storage is offline"
  type        = bool
  default     = false
}

variable "protection" {
  description = "Prevent accidental deletion in Proxmox UI and API"
  type        = bool
  default     = true
}

variable "unprivileged" {
  type    = bool
  default = true
}
