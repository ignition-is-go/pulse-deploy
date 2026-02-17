# proxmox-vm

Creates a single Proxmox VM by full-cloning a template. Supports PCI passthrough (GPU, CX6 SR-IOV VFs) and cloud-init network configuration.

## Usage

```hcl
module "render_node" {
  source = "./modules/proxmox-vm"

  id             = 201
  name           = "windows-unreal-01"
  node_name      = "pve-01"
  template_id    = 9000
  cores          = 16
  memory_mb      = 65536
  disk_gb        = 500
  datastore_id   = "zfs-nvme-01"
  os_type        = "win11"

  pci_devices = [{
    device = "hostpci0"
    id     = "0000:41:00"
    xvga   = true
    pcie   = true
    rombar = true
  }]

  cloud_init = {
    ip      = "192.168.1.101"
    gateway = "192.168.1.1"
    dns     = ["192.168.1.1"]
  }
}
```

## Behavior

- Sets q35 machine type automatically when PCI devices are present
- Creates EFI disk only when `override_bios = "ovmf"`
- Linux VMs: pass `ssh_keys` in `cloud_init` to inject authorized keys
- Windows VMs: omit `ssh_keys` — cloudbase-init handles user setup
- `protection = true` by default — prevents accidental deletion in Proxmox
- Ignores disk size drift in lifecycle (manual resizes are preserved)
