# =============================================================================
# VM Type Catalog
#
# All VM types get a CX6 VF when available (high-speed media network).
#
#   Type                  OS           GPU     Notes
#   ──────────────────    ──────────   ──────  ─────────────────────────────────
#   UE content            Windows VM   yes     nDisplay content cluster nodes
#   UE previs             Windows VM   yes     nDisplay previs cluster nodes
#   Touch                 Windows VM   yes     TouchDesigner, volumetric content
#   Arnold/Fusion         Windows VM   yes     Offline render + compositing
#   Workstation           Windows VM   yes     Content creation, RDP
#   UE plugin dev         Windows VM   yes     UE editor for plugin development
#   UE runner             Windows VM   no      Headless UE automation runner
#   UE build              Windows VM   no      Headless UE cook/package
#   UE staging            Windows VM   no      Plastic sync, build distribution
#   Optik                 Linux VM     yes     Computer vision (DeepStream)
#   rship                 LXC          no      Real-time data worker
#   pulse-admin           LXC          no      Control plane (Ansible, monitoring)
#   pixelfarm             LXC          no      Render job orchestration
#   rustdesk              LXC          no      Remote desktop server
#
# Content pipeline:
#   Artists (workstations) → Plastic SCM → ┬─ Staging (sync + robocopy)  → editor launch  = rehearsal
#                                          └─ Build (cook/package)       → packaged build = production
#
# Hostname scheme: {type}-{NN}  (max 15 chars — Windows NetBIOS limit)
#
#   ue-content-01..NN      nDisplay content render nodes       (13)
#   ue-previs-01..NN       nDisplay previs render nodes        (12)
#   touch-01..NN           TouchDesigner                       ( 8)
#   arnold-01..NN          Arnold/Fusion offline render         ( 9)
#   workstation-01..NN     Artist workstations                 (14)
#   ue-plugindev-01..NN   UE plugin development               (15)
#   ue-runner-01..NN       Headless UE automation              (12)
#   ue-build-01..NN        UE cook/package                     (11)
#   ue-staging-01..NN      Plastic sync + distribution         (13)
#   optik-01..NN           Computer vision                     ( 8)
#   rship-01..NN           rship workers (LXC)                 ( 8)
#   pulse-admin-01..NN     Control plane (LXC)                 (14)
#   pixelfarm-01..NN       Render job orchestration (LXC)      (12)
#   rustdesk-01..NN        RustDesk server (LXC)               (10)
#
# Role assignment (content vs previs, nDisplay node ID, etc.) lives in
# Ansible inventory groups, not hostnames. Physical host placement lives
# in Terraform, not hostnames.
# =============================================================================

# =============================================================================
# IP Plan (192.168.1.0/24) — see docs/network-ip-schema.md for full detail
#
#   .1-.99      PHYSICAL      everything with a chassis
#   .100-.149   DEV GUESTS    VMs/LXCs on nyc-dev-pve-*
#   .150-.199   PROD GUESTS   VMs/LXCs on nyc-prod-pve-*
#   .200-.254   DHCP          temporary / unmanaged
#
# VM ID = 1000 + last octet
#
# Dev guests (.100-.149):
#   .101        pulse-admin-dev
#   .111-.114   ue-staging
#   .121-.124   ue-editing
#   .126-.129   workstation
#   .131-.134   ue-plugindev
#   .141-.144   ue-runner
#
# Prod guests (.150-.199):
#   .151        pulse-admin
#   .161-.176   ue-content
#   .181-.184   ue-previs
#   .185-.189   touch
#   .191-.199   optik
# =============================================================================

# -----------------------------------------------------------------------------
# Proxmox connection
# -----------------------------------------------------------------------------

proxmox_endpoint = "https://192.168.1.51:8006"
proxmox_username = "root@pam"
# proxmox_password in secrets.auto.tfvars

# -----------------------------------------------------------------------------
# Proxmox hosts — physical hardware inventory
# -----------------------------------------------------------------------------

proxmox_hosts = {
  # --- Production (5x identical) ---
  # 2x AMD EPYC 9575F 64-Core (2 sockets, SMT off)
  # 8x RTX 6000 Ada, 2x CX6 + 1x BlueField-2 (8 VFs on 92:00.x)
  # zfs-nvme-01 ~6.7T

  "nyc-prod-pve-01" = {
    cores      = 128
    memory_gb  = 1133
    storage_gb = 6700
    storage_id = "zfs-nvme-01"
    gpus = [
      "0000:63:00.0",
      "0000:d6:00.0",
      "0000:d7:00.0",
      "0000:da:00.0",
      "0000:e0:00.0",
      "", # TBD — slot 5
      "", # TBD — slot 6
      "", # TBD — slot 7
    ]
    cx6_vfs = [
      "0000:92:00.2",
      "0000:92:00.3",
      "0000:92:00.4",
      "0000:92:00.5",
      "0000:92:00.6",
      "0000:92:00.7",
      "0000:92:01.0",
      "0000:92:01.1",
    ]
  }

  "nyc-prod-pve-02" = {
    cores      = 128
    memory_gb  = 1133
    storage_gb = 6700
    storage_id = "zfs-nvme-02"
    gpus = [
      "0000:63:00.0",
      "0000:d6:00.0",
      "0000:d7:00.0",
      "0000:da:00.0",
      "0000:e0:00.0",
      "", # TBD — slot 5
      "", # TBD — slot 6
      "", # TBD — slot 7
    ]
    cx6_vfs = [
      "0000:92:00.2",
      "0000:92:00.3",
      "0000:92:00.4",
      "0000:92:00.5",
      "0000:92:00.6",
      "0000:92:00.7",
      "0000:92:01.0",
      "0000:92:01.1",
    ]
  }

  "nyc-prod-pve-03" = {
    cores      = 0  # TBD — node offline
    memory_gb  = 0  # TBD
    storage_gb = 0  # TBD
    storage_id = "" # TBD
    gpus       = [] # TBD
    cx6_vfs    = [] # TBD
  }

  "nyc-prod-pve-04" = {
    cores      = 0  # TBD — node offline
    memory_gb  = 0  # TBD
    storage_gb = 0  # TBD
    storage_id = "" # TBD
    gpus       = [] # TBD
    cx6_vfs    = [] # TBD
  }

  "nyc-prod-pve-05" = {
    cores      = 0  # TBD — node offline
    memory_gb  = 0  # TBD
    storage_gb = 0  # TBD
    storage_id = "" # TBD
    gpus       = [] # TBD
    cx6_vfs    = [] # TBD
  }

  # --- Dev (3x) ---

  "nyc-dev-pve-01" = {
    cores      = 0  # TBD
    memory_gb  = 0  # TBD
    storage_gb = 0  # TBD
    storage_id = "" # TBD
    gpus       = [] # TBD
    cx6_vfs    = [] # TBD
  }

  # 1x AMD EPYC 9474F 48-Core (1 socket, SMT on = 96 threads)
  # 2x RTX 4090, 1x CX6 (VF PCI IDs TBD — run lspci on host)
  # zfs-nvme-04
  "nyc-dev-pve-02" = {
    cores      = 96
    memory_gb  = 251
    storage_gb = 7020 # TODO: verify with `zpool list` on host
    storage_id = "zfs-nvme-04"
    gpus = [
      "0000:01:00.0", # RTX 4090
      "0000:81:00.0", # RTX 4090
    ]
    cx6_vfs = [] # TBD: lspci -nn | grep -i mellanox
  }

  # 1x AMD EPYC 9474F 48-Core (1 socket, SMT on = 96 threads)
  # 6x RTX A4000, 1x BlueField-2 CX6 Dx (8 VFs on 81:00.x)
  # zfs-nvme-05 ~7T, local 94G (root only)
  "nyc-dev-pve-03" = {
    cores      = 96
    memory_gb  = 251
    storage_gb = 7020
    storage_id = "zfs-nvme-05"
    gpus = [
      "0000:01:00",
      "0000:02:00",
      "0000:41:00",
      "0000:82:00",
      "0000:c1:00",
      "0000:c2:00",
    ]
    cx6_vfs = [
      "0000:81:00.2",
      "0000:81:00.3",
      "0000:81:00.4",
      "0000:81:00.5",
      "0000:81:00.6",
      "0000:81:00.7",
      "0000:81:01.0",
      "0000:81:01.1",
    ]
  }
}

# -----------------------------------------------------------------------------
# Templates
# -----------------------------------------------------------------------------

windows_template_ids = {
  "nyc-prod-pve-01" = 6102 # win25-9575f-cloudinit-01
  "nyc-prod-pve-02" = 6103 # win25-9575f-cloudinit-02
  "nyc-prod-pve-03" = 0    # TBD — node offline
  "nyc-prod-pve-04" = 0    # TBD — node offline
  "nyc-prod-pve-05" = 0    # TBD — node offline
  "nyc-dev-pve-02"  = 6009 # win25-9474f-cloudinit-02
  "nyc-dev-pve-03"  = 6008 # win25-9474f-cloudinit-03
}
linux_template_id   = 9001
lxc_template        = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"

# -----------------------------------------------------------------------------
# Network
# -----------------------------------------------------------------------------

# windows_admin_password in secrets.auto.tfvars

network_bridge  = "vmbr0"
network_gateway = "192.168.1.1"
dns_servers     = ["192.168.1.1"]

# -----------------------------------------------------------------------------
# SSH key for Linux targets
# -----------------------------------------------------------------------------

ssh_public_key = "ssh-ed25519 AAAA... user@control-plane"

# =============================================================================
# Node definitions — gpu_slots index into proxmox_hosts[node].gpus,
#                    cx6_slot indexes into proxmox_hosts[node].cx6_vfs
# =============================================================================

# -----------------------------------------------------------------------------
# pulse_admin (LXC)                                                    .151
# -----------------------------------------------------------------------------

pulse_admin = {}

# -----------------------------------------------------------------------------
# pixelfarm (LXC)                                                      .xxx
# -----------------------------------------------------------------------------

pixelfarm = {}

# -----------------------------------------------------------------------------
# rustdesk (LXC)                                                       .xx
# -----------------------------------------------------------------------------

rustdesk = {}

# -----------------------------------------------------------------------------
# arnold_fusion (Windows + GPU)                                        .xxx
# -----------------------------------------------------------------------------

arnold_fusion = {}

# -----------------------------------------------------------------------------
# ue_build (Windows, no GPU)                                           .xxx
# -----------------------------------------------------------------------------

ue_build = {}

# -----------------------------------------------------------------------------
# ue_plugin_dev (Windows + GPU)                                        .131-.134
# -----------------------------------------------------------------------------

ue_plugin_dev = {
  "ue-plugindev-01" = {
    id        = 1131
    ip        = "192.168.1.131"
    node      = "nyc-dev-pve-03"
    cores     = 16
    memory_mb = 32768
    disk_gb   = 300
    gpu_slots = [0]
  }
  "ue-plugindev-02" = {
    id        = 1132
    ip        = "192.168.1.132"
    node      = "nyc-dev-pve-03"
    cores     = 16
    memory_mb = 32768
    disk_gb   = 300
    gpu_slots = [1]
  }
}

# -----------------------------------------------------------------------------
# win_ue_runner (Windows, no GPU)                                      .141-.144
# -----------------------------------------------------------------------------

win_ue_runner = {
  "ue-runner-01" = {
    id        = 1141
    ip        = "192.168.1.141"
    node      = "nyc-dev-pve-03"
    cores     = 16
    memory_mb = 32768
    disk_gb   = 300
  }
}

# -----------------------------------------------------------------------------
# ue_staging (Windows, no GPU)                                         .111-.114
# -----------------------------------------------------------------------------

ue_staging = {
  "ue-staging-01" = {
    id        = 1111
    ip        = "192.168.1.111"
    node      = "nyc-dev-pve-03"
    cores     = 16
    memory_mb = 98304
    disk_gb   = 300
  }
}

# -----------------------------------------------------------------------------
# touch (Windows + GPU)                                                .185-.189
# -----------------------------------------------------------------------------

touch = {
  # "touch-01" = {
  #   id        = 1185
  #   ip        = "192.168.1.185"
  #   node      = "nyc-prod-pve-02"
  #   cores     = 16
  #   memory_mb = 98304
  #   disk_gb   = 200
  #   gpu_slots = [0]
  #   cx6_slot  = 0
  # }
}

# -----------------------------------------------------------------------------
# optik (Linux + GPU)                                                  .191-.199
# -----------------------------------------------------------------------------

optik = {}

# -----------------------------------------------------------------------------
# rship (LXC)                                                         .xxx
# -----------------------------------------------------------------------------

rship = {}

# -----------------------------------------------------------------------------
# workstation (Windows + GPU)                                          .126-.129
# -----------------------------------------------------------------------------

workstation = {
  "workstation-01" = {
    id        = 1126
    ip        = "192.168.1.126"
    node      = "nyc-dev-pve-02"
    cores     = 16
    memory_mb = 98304
    disk_gb   = 300
    gpu_slots = [0]
  }
}

# -----------------------------------------------------------------------------
# ue_content (Windows + GPU)                                           .161-.176
# -----------------------------------------------------------------------------

ue_content = {
  "ue-content-01" = {
    id               = 1161
    ip               = "192.168.1.161"
    media_ip         = "10.0.0.161"
    ndisplay_node    = "Node_1"
    ndisplay_primary = true
    node             = "nyc-prod-pve-01"
    cores            = 16
    memory_mb        = 98304
    disk_gb          = 300
    gpu_slots        = [0]
    cx6_slot         = 0
  }
}

# -----------------------------------------------------------------------------
# ue_previs (Windows + GPU)                                            .181-.184
# -----------------------------------------------------------------------------

ue_previs = {
  # "ue-previs-01" = {
  #   id        = 1181
  #   ip        = "192.168.1.181"
  #   node      = "nyc-prod-pve-01"
  #   cores     = 16
  #   memory_mb = 98304
  #   disk_gb   = 300
  #   gpu_slots = [4]
  #   cx6_slot  = 4
  # }
}
