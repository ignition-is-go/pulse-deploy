# =============================================================================
# VM Type Catalog
#
# GPU VMs get two CX6 VFs: media (Rivermax) + storage (SMB Direct).
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
#   UE staging            Windows VM   no      Plastic sync, build distribution
#   Optik                 Linux VM     yes     Computer vision (DeepStream)
#   rship                 LXC          no      Real-time data worker
#   pulse-admin           LXC          no      Control plane (Ansible, monitoring)
#   pixelfarm             LXC          no      Render job orchestration
#   rustdesk              LXC          no      Remote desktop server
#
# Content pipeline:
#   Artists (workstations) → Plastic SCM → Staging (sync + robocopy) → editor launch = rehearsal
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
#   .1-.99      PHYSICAL      hosts + pulse-admin LXC (.70)
#   .100-.159   DEV GUESTS    VMs/LXCs on nyc-dev-pve-*
#   .160-.199   PROD GUESTS   VMs/LXCs on nyc-prod-pve-*
#   .200-.254   DHCP          temporary / unmanaged
#
# VM ID = 1000 + last octet
#
# Dev guests (.100-.159):
#   .101-.109   optik
#   .111-.114   ue-staging
#   .121-.124   ue-editing
#   .126-.129   workstation
#   .131-.134   ue-plugindev
#   .141-.144   ue-runner
#   .150-.159   arnold/fusion
#
# Prod guests (.160-.199):
#   .161-.176   ue-content
#   .177-.180   ue-editing
#   .181-.184   ue-previs
#   .185-.189   touch
#   .191-.194   optik
#   .195-.199   workstation
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
  # 8x RTX 6000 Ada, 2x CX6 (16 VFs each)
  # zfs-nvme-01 ~6.7T

  "nyc-prod-pve-01" = {
    ip         = "192.168.1.51"
    cores      = 128
    memory_gb  = 1133
    storage_gb = 6700
    storage_id = "zfs-nvme-01"
    gpus = [
      "0000:5b:00.0",
      "0000:5e:00.0",
      "0000:63:00.0",
      "0000:64:00.0",
      "0000:d6:00.0",
      "0000:d7:00.0",
      "0000:da:00.0",
      "0000:e0:00.0",
    ]
    cx6_vfs = [
      # Card 1 (5a) — VF0-15
      "0000:5a:00.2",
      "0000:5a:00.3",
      "0000:5a:00.4",
      "0000:5a:00.5",
      "0000:5a:00.6",
      "0000:5a:00.7",
      "0000:5a:01.0",
      "0000:5a:01.1",
      "0000:5a:01.2",
      "0000:5a:01.3",
      "0000:5a:01.4",
      "0000:5a:01.5",
      "0000:5a:01.6",
      "0000:5a:01.7",
      "0000:5a:02.0",
      "0000:5a:02.1",
      # Card 2 (df) — VF0-15
      "0000:df:00.2",
      "0000:df:00.3",
      "0000:df:00.4",
      "0000:df:00.5",
      "0000:df:00.6",
      "0000:df:00.7",
      "0000:df:01.0",
      "0000:df:01.1",
      "0000:df:01.2",
      "0000:df:01.3",
      "0000:df:01.4",
      "0000:df:01.5",
      "0000:df:01.6",
      "0000:df:01.7",
      "0000:df:02.0",
      "0000:df:02.1",
    ]
    sriov_cards = [
      {
        type       = "cx6"
        switchid   = "8ab2a00003f6ceb8"
        pci_slots  = ["0000:5a:00.0", "0000:5a:00.1"]
        pf_ifaces  = ["enp90s0f0np0", "enp90s0f1np1"]
        rep_prefix = "enp90s0f0r"
        bridge     = "vmbr1"
        bond       = "bond1"
      },
      {
        type       = "cx6"
        switchid   = "5a03d20003a1420c"
        pci_slots  = ["0000:df:00.0", "0000:df:00.1"]
        pf_ifaces  = ["enp223s0f0np0", "enp223s0f1np1"]
        rep_prefix = "enp223s0f0r"
        bridge     = "vmbr2"
        bond       = "bond2"
      },
    ]
  }

  "nyc-prod-pve-02" = {
    ip         = "192.168.1.61"
    cores      = 128
    memory_gb  = 1133
    storage_gb = 6700
    storage_id = "zfs-nvme-02"
    gpus = [
      "0000:5b:00.0",
      "0000:5e:00.0",
      "0000:63:00.0",
      "0000:64:00.0",
      "0000:d6:00.0",
      "0000:d7:00.0",
      "0000:da:00.0",
      "0000:e0:00.0",
    ]
    cx6_vfs = [
      # Card 1 (5a) — VF0-15
      "0000:5a:00.2",
      "0000:5a:00.3",
      "0000:5a:00.4",
      "0000:5a:00.5",
      "0000:5a:00.6",
      "0000:5a:00.7",
      "0000:5a:01.0",
      "0000:5a:01.1",
      "0000:5a:01.2",
      "0000:5a:01.3",
      "0000:5a:01.4",
      "0000:5a:01.5",
      "0000:5a:01.6",
      "0000:5a:01.7",
      "0000:5a:02.0",
      "0000:5a:02.1",
      # Card 2 (df) — VF0-15
      "0000:df:00.2",
      "0000:df:00.3",
      "0000:df:00.4",
      "0000:df:00.5",
      "0000:df:00.6",
      "0000:df:00.7",
      "0000:df:01.0",
      "0000:df:01.1",
      "0000:df:01.2",
      "0000:df:01.3",
      "0000:df:01.4",
      "0000:df:01.5",
      "0000:df:01.6",
      "0000:df:01.7",
      "0000:df:02.0",
      "0000:df:02.1",
    ]
    sriov_cards = [
      {
        type       = "cx6"
        switchid   = "0639e70003d23fb8"
        pci_slots  = ["0000:5a:00.0", "0000:5a:00.1"]
        pf_ifaces  = ["enp90s0f0np0", "enp90s0f1np1"]
        rep_prefix = "enp90s0f0r"
        bridge     = "vmbr1"
        bond       = "bond1"
      },
      {
        type       = "cx6"
        switchid   = "eab2a00003f6ceb8"
        pci_slots  = ["0000:df:00.0", "0000:df:00.1"]
        pf_ifaces  = ["enp223s0f0np0", "enp223s0f1np1"]
        rep_prefix = "enp223s0f0r"
        bridge     = "vmbr2"
        bond       = "bond2"
      },
    ]
  }

  "nyc-prod-pve-03" = {
    ip         = "" # TBD — node offline
    cores      = 0
    memory_gb  = 0
    storage_gb = 0
    storage_id = ""
    gpus       = []
    cx6_vfs    = []
  }

  "nyc-prod-pve-04" = {
    ip         = "" # TBD — node offline
    cores      = 0
    memory_gb  = 0
    storage_gb = 0
    storage_id = ""
    gpus       = []
    cx6_vfs    = []
  }

  "nyc-prod-pve-05" = {
    ip         = "" # TBD — node offline
    cores      = 0
    memory_gb  = 0
    storage_gb = 0
    storage_id = ""
    gpus       = []
    cx6_vfs    = []
  }

  # --- Dev (3x) ---

  "nyc-dev-pve-01" = {
    ip         = "" # TBD
    cores      = 0
    memory_gb  = 0
    storage_gb = 0
    storage_id = ""
    gpus       = []
    cx6_vfs    = []
  }

  # 1x AMD EPYC 9474F 48-Core (1 socket, SMT on = 96 threads)
  # 2x RTX 4090, 1x BlueField-2 (BF2 PCI 41:00.0, iface nic3)
  # zfs-nvme-04
  "nyc-dev-pve-02" = {
    ip         = "192.168.1.42"
    cores      = 96
    memory_gb  = 251
    storage_gb = 7020 # TODO: verify with `zpool list` on host
    storage_id = "zfs-nvme-04"
    gpus = [
      "0000:01:00.0", # RTX 4090
      "0000:81:00.0", # RTX 4090
    ]
    cx6_vfs = [
      "0000:41:00.2",
      "0000:41:00.3",
      "0000:41:00.4",
      "0000:41:00.5",
      "0000:41:00.6",
      "0000:41:00.7",
      "0000:41:01.0",
      "0000:41:01.1",
    ]
    sriov_cards = [
      {
        type      = "bf2"
        pci_slots = ["0000:41:00.0"]
        bf2_iface = "nic3"
      },
    ]
  }

  # 1x AMD EPYC 9474F 48-Core (1 socket, SMT on = 96 threads)
  # 6x RTX A4000, 1x BlueField-2 CX6 Dx (16 VFs on 81:00.x)
  # zfs-nvme-05 ~7T, local 94G (root only)
  "nyc-dev-pve-03" = {
    ip         = "192.168.1.43"
    cores      = 96
    memory_gb  = 251
    storage_gb = 7020
    storage_id = "zfs-nvme-05"
    gpus = [
      "0000:01:00.0",
      "0000:02:00.0",
      "0000:41:00.0",
      "0000:82:00.0",
      "0000:c1:00.0",
      "0000:c2:00.0",
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
      "0000:81:01.2",
      "0000:81:01.3",
      "0000:81:01.4",
      "0000:81:01.5",
      "0000:81:01.6",
      "0000:81:01.7",
      "0000:81:02.0",
      "0000:81:02.1",
    ]
    sriov_cards = [
      {
        type      = "bf2"
        pci_slots = ["0000:81:00.0"]
        bf2_iface = "nic3"
      },
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
linux_template_ids = {
  "nyc-prod-pve-01" = 0    # TBD
  "nyc-prod-pve-02" = 0    # TBD
  "nyc-dev-pve-02"  = 6508 # ubuntu-desktop-cloudinit-02
  "nyc-dev-pve-03"  = 6509 # ubuntu-desktop-cloudinit-03
}
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

ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJXsqKssyL5gDAe/uUE+z3Lt+rb9vqgi1Y6YT4wsQBHI"

# =============================================================================
# Node definitions — gpu_slots index into proxmox_hosts[node].gpus,
#                    cx6_card + cx6_vf_offsets resolve to proxmox_hosts[node].cx6_vfs
# =============================================================================

# -----------------------------------------------------------------------------
# pulse_admin (LXC)                                                    .160
# -----------------------------------------------------------------------------

pulse_admin = {}

# -----------------------------------------------------------------------------
# pbs (physical)                                                         .31
# -----------------------------------------------------------------------------

pbs = {
  "nyc-pbs-01" = {
    ip = "192.168.1.31"
  }
}

# -----------------------------------------------------------------------------
# pixelfarm (LXC)                                                      .xxx
# -----------------------------------------------------------------------------

pixelfarm = {}

# -----------------------------------------------------------------------------
# rustdesk (LXC)                                                       .xx
# -----------------------------------------------------------------------------

rustdesk = {}

# -----------------------------------------------------------------------------
# arnold_fusion (Windows + GPU)                                        .151-.159
# -----------------------------------------------------------------------------

arnold_fusion = {}


# -----------------------------------------------------------------------------
# ue_plugindev (Windows + GPU)                                        .131-.134
# -----------------------------------------------------------------------------

ue_plugindev = {
  "ue-plugindev-01" = {
    id        = 1131
    ip        = "192.168.1.131"
    ip_2110   = "10.0.0.131"
    ip_smb    = "10.0.1.131"
    node      = "nyc-dev-pve-03"
    cores     = 16
    memory_mb = 32768
    disk_gb   = 300
    gpu_slots = [0]
    cx6_card       = 0
    cx6_vf_offsets = [0, 1]
    extra_tags = ["canary"]
  }
  "ue-plugindev-02" = {
    id        = 1132
    ip        = "192.168.1.132"
    ip_2110   = "10.0.0.132"
    ip_smb    = "10.0.1.132"
    node      = "nyc-dev-pve-03"
    cores     = 16
    memory_mb = 32768
    disk_gb   = 300
    gpu_slots = [1]
    cx6_card       = 0
    cx6_vf_offsets = [2, 3]
    extra_tags = ["trev-dev"]
  }
}

# -----------------------------------------------------------------------------
# ue_runner (Windows, no GPU)                                      .141-.144
# -----------------------------------------------------------------------------

ue_runner = {
  "ue-runner-01" = {
    id        = 1141
    ip        = "192.168.1.141"
    node      = "nyc-dev-pve-03"
    cores     = 16
    memory_mb = 32768
    disk_gb   = 300
    started   = false
  }
}

# -----------------------------------------------------------------------------
# ue_staging (Windows, no GPU)                                         .111-.114
# -----------------------------------------------------------------------------

ue_staging = {
  "ue-staging-01" = {
    id             = 1111
    ip             = "192.168.1.111"
    ip_smb         = "10.0.1.111"
    node           = "nyc-dev-pve-03"
    cores          = 16
    memory_mb      = 32768
    disk_gb        = 300
    cx6_card       = 0
    cx6_vf_offsets = [4]
    started        = true
  }
}

# -----------------------------------------------------------------------------
# touch (Windows + GPU)                                                .185-.189
# -----------------------------------------------------------------------------

touch = {
  "touch-01" = {
    id         = 1185
    ip         = "192.168.1.185"
    ip_2110   = "10.0.0.185"
    ip_smb = "10.0.1.185"
    node       = "nyc-prod-pve-01"
    cores     = 16
    memory_mb = 98304
    disk_gb   = 300
    gpu_slots = [7]
    cx6_card       = 1
    cx6_vf_offsets = [12, 13]
    started        = false
  }
  "touch-02" = {
    id             = 1186
    ip             = "192.168.1.186"
    ip_2110        = "10.0.0.186"
    ip_smb         = "10.0.1.186"
    node           = "nyc-prod-pve-02"
    cores          = 16
    memory_mb      = 98304
    disk_gb        = 300
    gpu_slots      = [3]
    cx6_card       = 1
    cx6_vf_offsets = [8, 9]
    started        = true
  }
}

# -----------------------------------------------------------------------------
# optik (Linux + GPU)                                                  .191-.199
# -----------------------------------------------------------------------------

optik = {
  "optik-dev-01" = {
    id             = 1101
    ip             = "192.168.1.101"
    node           = "nyc-dev-pve-03"
    cores          = 32
    memory_mb      = 49152
    disk_gb        = 256
    gpu_slots      = [2, 3, 4, 5]
    cx6_card       = 0
    cx6_vf_offsets = [5, 6]
    started        = true
  }
}

# -----------------------------------------------------------------------------
# rship (LXC)                                                         .xxx
# -----------------------------------------------------------------------------

rship = {}

# -----------------------------------------------------------------------------
# workstation (Windows + GPU)                                          .126-.129
# -----------------------------------------------------------------------------

workstation = {
  "workstation-01" = {
    id         = 1126
    ip         = "192.168.1.126"
    ip_2110    = "10.0.0.126"
    ip_smb     = "10.0.1.126"
    node       = "nyc-dev-pve-02"
    cores      = 32
    memory_mb  = 49152
    disk_gb    = 300
    gpu_slots  = [0]
    cx6_card       = 0
    cx6_vf_offsets = [0, 1]
    extra_tags = ["jaksa"]
  }
  "workstation-02" = {
    id         = 1127
    ip         = "192.168.1.127"
    ip_2110    = "10.0.0.127"
    ip_smb     = "10.0.1.127"
    node       = "nyc-dev-pve-02"
    cores      = 32
    memory_mb  = 49152
    disk_gb    = 300
    gpu_slots  = [1]
    cx6_card       = 0
    cx6_vf_offsets = [2, 3]
    extra_tags = ["mateo"]
  }
  "workstation-03" = {
    id         = 1195
    ip         = "192.168.1.195"
    ip_2110    = "10.0.0.195"
    ip_smb     = "10.0.1.195"
    node       = "nyc-prod-pve-01"
    cores      = 32
    memory_mb  = 98304
    disk_gb    = 300
    gpu_slots  = [5]
    cx6_card       = 1
    cx6_vf_offsets = [8, 9]
    started        = false
  }
  "workstation-04" = {
    id         = 1196
    ip         = "192.168.1.196"
    ip_2110    = "10.0.0.196"
    ip_smb     = "10.0.1.196"
    node       = "nyc-prod-pve-01"
    cores      = 32
    memory_mb  = 98304
    disk_gb    = 300
    gpu_slots  = [6]
    cx6_card       = 1
    cx6_vf_offsets = [10, 11]
    started        = false
  }
}

# -----------------------------------------------------------------------------
# ue_content (Windows + GPU)                                           .161-.176
# -----------------------------------------------------------------------------

ue_content = {
  # --- nyc-prod-pve-01 (nodes 01-08) --- NUMA 0: slots 0-3, NUMA 1: slots 4-7
  "ue-content-01" = {
    id               = 1161
    ip               = "192.168.1.161"
    ip_2110         = "10.0.0.161"
    ip_smb       = "10.0.1.161"
    ndisplay_node    = "Node_1"
    ndisplay_primary = true
    node             = "nyc-prod-pve-01"
    cores            = 16
    memory_mb        = 98304
    disk_gb          = 300
    gpu_slots        = [0]
    cx6_card         = 0
    cx6_vf_offsets   = [0, 1]
    numa_node        = 0
    cpu_affinity     = "0-15"
    started          = true
  }
  "ue-content-02" = {
    id               = 1162
    ip               = "192.168.1.162"
    ip_2110         = "10.0.0.162"
    ip_smb       = "10.0.1.162"
    ndisplay_node    = "Node_2"
    node             = "nyc-prod-pve-01"
    cores            = 16
    memory_mb        = 98304
    disk_gb          = 300
    gpu_slots        = [1]
    cx6_card         = 0
    cx6_vf_offsets   = [2, 3]
    numa_node        = 0
    cpu_affinity     = "16-31"
    started          = true
  }
  "ue-content-03" = {
    id               = 1163
    ip               = "192.168.1.163"
    ip_2110         = "10.0.0.163"
    ip_smb       = "10.0.1.163"
    ndisplay_node    = "Node_3"
    node             = "nyc-prod-pve-01"
    cores            = 16
    memory_mb        = 98304
    disk_gb          = 300
    gpu_slots        = [2]
    cx6_card         = 0
    cx6_vf_offsets   = [4, 5]
    numa_node        = 0
    cpu_affinity     = "32-47"
    started          = true
  }
  "ue-content-04" = {
    id               = 1164
    ip               = "192.168.1.164"
    ip_2110         = "10.0.0.164"
    ip_smb       = "10.0.1.164"
    ndisplay_node    = "Node_4"
    node             = "nyc-prod-pve-01"
    cores            = 16
    memory_mb        = 98304
    disk_gb          = 300
    gpu_slots        = [3]
    cx6_card         = 0
    cx6_vf_offsets   = [6, 7]
    numa_node        = 0
    cpu_affinity     = "48-63"
    started          = true
  }
  "ue-content-05" = {
    id               = 1165
    ip               = "192.168.1.165"
    ip_2110         = "10.0.0.165"
    ip_smb       = "10.0.1.165"
    ndisplay_node    = "Node_5"
    node             = "nyc-prod-pve-01"
    cores            = 16
    memory_mb        = 98304
    disk_gb          = 300
    gpu_slots        = [4]
    cx6_card         = 1
    cx6_vf_offsets   = [0, 1]
    numa_node        = 1
    cpu_affinity     = "64-79"
    started          = true
  }
  "ue-content-06" = {
    id               = 1166
    ip               = "192.168.1.166"
    ip_2110         = "10.0.0.166"
    ip_smb       = "10.0.1.166"
    ndisplay_node    = "Node_6"
    node             = "nyc-prod-pve-01"
    cores            = 16
    memory_mb        = 98304
    disk_gb          = 300
    gpu_slots        = [5]
    cx6_card         = 1
    cx6_vf_offsets   = [2, 3]
    numa_node        = 1
    cpu_affinity     = "80-95"
    started          = true
  }
  "ue-content-07" = {
    id               = 1167
    ip               = "192.168.1.167"
    ip_2110         = "10.0.0.167"
    ip_smb       = "10.0.1.167"
    ndisplay_node    = "Node_7"
    node             = "nyc-prod-pve-01"
    cores            = 16
    memory_mb        = 98304
    disk_gb          = 300
    gpu_slots        = [6]
    cx6_card         = 1
    cx6_vf_offsets   = [4, 5]
    numa_node        = 1
    cpu_affinity     = "96-111"
    started          = true
  }
  "ue-content-08" = {
    id               = 1168
    ip               = "192.168.1.168"
    ip_2110         = "10.0.0.168"
    ip_smb       = "10.0.1.168"
    ndisplay_node    = "Node_8"
    node             = "nyc-prod-pve-01"
    cores            = 16
    memory_mb        = 98304
    disk_gb          = 300
    gpu_slots        = [7]
    cx6_card         = 1
    cx6_vf_offsets   = [6, 7]
    numa_node        = 1
    cpu_affinity     = "112-127"
    started          = true
  }
  # --- nyc-prod-pve-02 (nodes 09-16) --- NUMA 0: slots 0-3, NUMA 1: slots 4-7
  "ue-content-09" = {
    id               = 1169
    ip               = "192.168.1.169"
    ip_2110         = "10.0.0.169"
    ip_smb       = "10.0.1.169"
    ndisplay_node    = "Node_1"
    ndisplay_primary = true
    node             = "nyc-prod-pve-02"
    cores            = 16
    memory_mb        = 98304
    disk_gb          = 300
    gpu_slots        = [0]
    cx6_card         = 0
    cx6_vf_offsets   = [0, 1]
    numa_node        = 0
    cpu_affinity     = "0-15"
    started          = false
  }
  "ue-content-10" = {
    id               = 1170
    ip               = "192.168.1.170"
    ip_2110         = "10.0.0.170"
    ip_smb       = "10.0.1.170"
    ndisplay_node    = "Node_2"
    node             = "nyc-prod-pve-02"
    cores            = 16
    memory_mb        = 98304
    disk_gb          = 300
    gpu_slots        = [1]
    cx6_card         = 0
    cx6_vf_offsets   = [2, 3]
    numa_node        = 0
    cpu_affinity     = "16-31"
    started          = false
  }
  "ue-content-11" = {
    id               = 1171
    ip               = "192.168.1.171"
    ip_2110         = "10.0.0.171"
    ip_smb       = "10.0.1.171"
    ndisplay_node    = "Node_3"
    node             = "nyc-prod-pve-02"
    cores            = 16
    memory_mb        = 98304
    disk_gb          = 300
    gpu_slots        = [2]
    cx6_card         = 0
    cx6_vf_offsets   = [4, 5]
    numa_node        = 0
    cpu_affinity     = "32-47"
    started          = false
  }
  "ue-content-12" = {
    id               = 1172
    ip               = "192.168.1.172"
    ip_2110         = "10.0.0.172"
    ip_smb       = "10.0.1.172"
    ndisplay_node    = "Node_4"
    node             = "nyc-prod-pve-02"
    cores            = 16
    memory_mb        = 98304
    disk_gb          = 300
    gpu_slots        = [3]
    cx6_card         = 0
    cx6_vf_offsets   = [6, 7]
    numa_node        = 0
    cpu_affinity     = "48-63"
    started          = false
  }
  "ue-content-13" = {
    id               = 1173
    ip               = "192.168.1.173"
    ip_2110         = "10.0.0.173"
    ip_smb       = "10.0.1.173"
    ndisplay_node    = "Node_5"
    node             = "nyc-prod-pve-02"
    cores            = 16
    memory_mb        = 98304
    disk_gb          = 300
    gpu_slots        = [4]
    cx6_card         = 1
    cx6_vf_offsets   = [0, 1]
    numa_node        = 1
    cpu_affinity     = "64-79"
    started          = false
  }
  "ue-content-14" = {
    id               = 1174
    ip               = "192.168.1.174"
    ip_2110         = "10.0.0.174"
    ip_smb       = "10.0.1.174"
    ndisplay_node    = "Node_6"
    node             = "nyc-prod-pve-02"
    cores            = 16
    memory_mb        = 98304
    disk_gb          = 300
    gpu_slots        = [5]
    cx6_card         = 1
    cx6_vf_offsets   = [2, 3]
    numa_node        = 1
    cpu_affinity     = "80-95"
    started          = false
  }
  "ue-content-15" = {
    id               = 1175
    ip               = "192.168.1.175"
    ip_2110         = "10.0.0.175"
    ip_smb       = "10.0.1.175"
    ndisplay_node    = "Node_7"
    node             = "nyc-prod-pve-02"
    cores            = 16
    memory_mb        = 98304
    disk_gb          = 300
    gpu_slots        = [6]
    cx6_card         = 1
    cx6_vf_offsets   = [4, 5]
    numa_node        = 1
    cpu_affinity     = "96-111"
    started          = false
  }
  "ue-content-16" = {
    id               = 1176
    ip               = "192.168.1.176"
    ip_2110         = "10.0.0.176"
    ip_smb       = "10.0.1.176"
    ndisplay_node    = "Node_8"
    node             = "nyc-prod-pve-02"
    cores            = 16
    memory_mb        = 98304
    disk_gb          = 300
    gpu_slots        = [7]
    cx6_card         = 1
    cx6_vf_offsets   = [6, 7]
    numa_node        = 1
    cpu_affinity     = "112-127"
    started          = false
  }
}

# -----------------------------------------------------------------------------
# ue_editing (Windows + GPU) — Concert multi-user editor              .177-.180
# -----------------------------------------------------------------------------

ue_editing = {
  "ue-editing-01" = {
    id             = 1177
    ip             = "192.168.1.177"
    ip_2110        = "10.0.0.177"
    ip_smb         = "10.0.1.177"
    node           = "nyc-prod-pve-01"
    cores          = 16
    memory_mb      = 98304
    disk_gb        = 300
    gpu_slots      = [0]
    cx6_card       = 0
    cx6_vf_offsets = [8, 9]
    started        = false
  }
  "ue-editing-02" = {
    id             = 1178
    ip             = "192.168.1.178"
    ip_2110        = "10.0.0.178"
    ip_smb         = "10.0.1.178"
    node           = "nyc-prod-pve-02"
    cores          = 16
    memory_mb      = 98304
    disk_gb        = 300
    gpu_slots      = [2]
    cx6_card       = 0
    cx6_vf_offsets = [8, 9]
    started        = true
  }
}

# -----------------------------------------------------------------------------
# ue_previs (Windows + GPU)                                            .181-.184
# -----------------------------------------------------------------------------

ue_previs = {
  "ue-previs-01" = {
    id             = 1181
    ip             = "192.168.1.181"
    ip_2110        = "10.0.0.181"
    ip_smb         = "10.0.1.181"
    node           = "nyc-prod-pve-01"
    cores          = 16
    memory_mb      = 98304
    disk_gb        = 300
    gpu_slots      = [4]
    cx6_card       = 0
    cx6_vf_offsets = [10, 11]
    started        = false
  }
  "ue-previs-02" = {
    id             = 1182
    ip             = "192.168.1.182"
    ip_2110        = "10.0.0.182"
    ip_smb         = "10.0.1.182"
    node           = "nyc-prod-pve-02"
    cores          = 16
    memory_mb      = 98304
    disk_gb        = 300
    gpu_slots      = [1]
    cx6_card       = 0
    cx6_vf_offsets = [10, 11]
    started        = true
  }
}
