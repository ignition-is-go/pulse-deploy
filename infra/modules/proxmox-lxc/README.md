# proxmox-lxc

Creates a single unprivileged Proxmox LXC container from a template with static IP and SSH key injection.

## Usage

```hcl
module "rship" {
  source = "./modules/proxmox-lxc"

  id               = 301
  hostname         = "lxc-rship-01"
  node_name        = "pve-01"
  template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
  cores            = 4
  memory_mb        = 4096
  disk_gb          = 20
  datastore_id     = "zfs-nvme-01"
  ip               = "192.168.1.201"
  gateway          = "192.168.1.1"
  dns_servers      = ["192.168.1.1"]
  ssh_keys         = [file("~/.ssh/id_ed25519.pub")]
}
```

## Behavior

- Unprivileged by default (`unprivileged = true`)
- `protection = true` by default — prevents accidental deletion in Proxmox
- Ignores disk size drift in lifecycle (manual resizes are preserved)
