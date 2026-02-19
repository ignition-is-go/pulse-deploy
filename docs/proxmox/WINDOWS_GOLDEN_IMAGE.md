# Windows Cloudbase-Init Template

## Important: One Template Per CPU Family

Templates built on one CPU will fail sysprep when cloned to a host with a different CPU. Build a separate template on each CPU family.

| Template ID | Name                      | CPU         | Nodes              |
|-------------|---------------------------|-------------|---------------------|
| 6003        | win25-cloudinit-9575f     | EPYC 9575F  | nyc-prod-pve-01..05 |
| 6004        | win25-cloudinit-9474f     | EPYC 9474F  | nyc-dev-pve-03      |

Template IDs are mapped per-node in `infra/terraform.tfvars` → `windows_template_ids`.

## 1. Create the VM

Adjust `VMID`, `NODE`, `STORAGE`, and ISO paths for your target host.

```bash
VMID=6004
NODE="nyc-dev-pve-03"
STORAGE="zfs-nvme-05"

qm create $VMID \
  --name "win25-cloudinit-9474f" \
  --memory 16384 \
  --cores 8 \
  --sockets 1 \
  --cpu host \
  --machine q35 \
  --bios seabios \
  --ostype win11 \
  --agent 1 \
  --balloon 0 \
  --scsi0 ${STORAGE}:100 \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr0 \
  --ide2 local:iso/26100.1742.240906-0331.ge_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso,media=cdrom \
  --ide3 local:iso/virtio-win-0.1.271.iso,media=cdrom \
  --boot "order=ide2;scsi0"
```

Notes:
- `virtio-scsi-single` is required for iothread support (Terraform sets `iothread=1` on cloned disks)
- Do NOT attach a GPU — the template should be hardware-neutral. GPUs are added by Terraform at clone time via PCI passthrough.
- Do NOT add an EFI disk — we use seabios, not OVMF

## 2. Install Windows

1. Start the VM, open Proxmox console
2. Boot from the Windows ISO
3. Select **Windows Server 2025 Standard Evaluation (Desktop Experience)**
4. Accept license
5. When prompted for disk, click **Load Driver** → browse virtio-win CD → `vioscsi\2k25\amd64`
6. Select Disk 0 Unallocated Space → Next
7. Set Administrator password

## 3. Post-Installation

### VirtIO drivers + QEMU Guest Agent

1. Open the virtio-win CD in Explorer
2. Run `virtio-win-gt-x64.exe` (installs all VirtIO drivers)
3. Run `virtio-win-guest-tools.exe` (installs QEMU Guest Agent + SPICE)
4. Verify guest agent: `Get-Service QEMU-GA` should show Running

### Windows Updates

Install all available updates, reboot as needed. Repeat until clean.

## 4. Install Cloudbase-Init

1. Download from https://cloudbase.it/cloudbase-init/
2. Run the installer
3. At the final screen, **uncheck** "Run Sysprep" — do NOT let the installer sysprep
4. Finish the installer
5. Replace the config files in `C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\` with the versions from this repo:
   - `infra/files/cloudbase-init/cloudbase-init.conf`
   - `infra/files/cloudbase-init/cloudbase-init-unattend.conf`

Cloudbase-init handles on first boot of each clone:
- Set hostname (from Proxmox VM name)
- Set Administrator password (from `cipassword`)
- Configure static IP, gateway, DNS (from cloud-init config)
- Extend disk volumes

## 5. Clean Up ISOs

Remove the CD-ROM drives before sysprep:

```bash
qm set $VMID --delete ide2
qm set $VMID --delete ide3
```

## 6. Sysprep and Shut Down

From inside the VM:

```powershell
& "C:\Windows\System32\Sysprep\sysprep.exe" `
  /generalize /oobe /shutdown `
  /unattend:"C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\Unattend.xml"
```

Wait for the VM to shut down on its own. Do not interrupt.

## 7. Convert to Template

```bash
qm template $VMID
```

## 8. Update Terraform

Add the template ID to `infra/terraform.tfvars`:

```hcl
windows_template_ids = {
  "nyc-prod-pve-01" = 6003  # win25-cloudinit-9575f
  ...
  "nyc-dev-pve-03"  = 6004  # win25-cloudinit-9474f
}
```

## Troubleshooting

### "Windows installation cannot proceed" after cloning

The template was built on a different CPU family. You need a template built natively on the target host. See the CPU family table above.

### Hostname not set after first boot

Cloudbase-init didn't complete its first-boot sequence. Rename manually:

```powershell
Rename-Computer -NewName "the-hostname" -Restart
```

### Password not working after first boot

Set it via Proxmox and reboot:

```bash
qm set <VMID> --cipassword 'YourPassword'
qm reboot <VMID>
```
