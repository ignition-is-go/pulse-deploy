# Cloudbase-Init Windows Template

Builds a Windows Server 2025 Datacenter Evaluation cloud-init template on an EPYC 9575F production node.

> **One template per CPU family.** Templates sysprep'd on one CPU fail when cloned to a different CPU. This template covers `nyc-prod-pve-01..05`.

## Variables

```
VMID=6102
NODE="nyc-prod-pve-01"
STORAGE="zfs-nvme-01"
```

Pick any prod node — all 5 have identical 9575F CPUs.

## 1. Create VM

```bash
qm create $VMID \
  --name "win25-cloudinit-9575f" \
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

- `virtio-scsi-single` — required for iothread support (Terraform sets `iothread=1` on clones)
- No GPU — template is hardware-neutral, GPUs added at clone time
- No EFI disk — seabios, not OVMF

## 2. Install Windows

1. Start VM, open Proxmox console
2. Boot from Windows ISO
3. Select **Windows Server 2025 Datacenter Evaluation (Desktop Experience)**
4. Accept license
5. Load driver → browse virtio-win CD → `vioscsi\2k25\amd64`
6. Select Disk 0 Unallocated Space → Next
7. Set Administrator password

## 3. Post-Install

### VirtIO drivers + QEMU Guest Agent

1. Open virtio-win CD in Explorer
2. Run `virtio-win-gt-x64.exe` (all VirtIO drivers)
3. Run `virtio-win-guest-tools.exe` (QEMU Guest Agent + SPICE)
4. Verify: `Get-Service QEMU-GA` should show Running

### Windows Updates

Install all available updates, reboot as needed. Repeat until clean.

### Remove Microsoft Edge

Edge's appx package blocks sysprep. Remove it before proceeding:

```powershell
Get-AppxPackage Microsoft.MicrosoftEdge.Stable | Remove-AppxPackage
```

## 4. Install Cloudbase-Init

1. Download from https://cloudbase.it/cloudbase-init/
2. Run installer — on the configuration page:
   - **Username:** `Administrator`
   - **Check** "Use metadata password"
   - **Uncheck** "Run Cloudbase-Init service as LocalSystem"
3. At final screen, **uncheck "Run Sysprep"**
4. Finish installer
5. Replace configs in `C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\`:
   - `cloudbase-init.conf` ← from `infra/files/cloudbase-init/cloudbase-init.conf`
   - `cloudbase-init-unattend.conf` ← from `infra/files/cloudbase-init/cloudbase-init-unattend.conf`
6. Copy `scripts/bootstrap-ansible.ps1` into `C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts\`

## 5. Remove ISOs + Reboot

```bash
qm set $VMID --delete ide2
qm set $VMID --delete ide3
```

Reboot the VM — IDE devices don't hot-unplug, so Windows still sees stale CD-ROMs until reboot.

## 6. Sysprep + Shutdown

From inside the VM:

```powershell
& "C:\Windows\System32\Sysprep\sysprep.exe" /generalize /oobe /shutdown /unattend:"C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\Unattend.xml"
```

Wait for the VM to shut down on its own. Do not interrupt.

## 7. Convert to Template

```bash
qm template $VMID
```

## 8. Update Terraform

In `infra/hrlv-dev/terraform.tfvars`, update `windows_template_ids`:

```hcl
windows_template_ids = {
  "nyc-prod-pve-01" = 6102 # win25-cloudinit-9575f
  "nyc-prod-pve-02" = 6102
  "nyc-prod-pve-03" = 6102
  "nyc-prod-pve-04" = 6102
  "nyc-prod-pve-05" = 6102
  "nyc-dev-pve-03"  = 6008 # win25-cloudinit-9474f
}
```

## Troubleshooting

### "Windows installation cannot proceed" after cloning
Template was built on a different CPU family. Need a template built natively on the target host.

### Hostname not set after first boot
Cloudbase-init didn't complete. Rename manually:
```powershell
Rename-Computer -NewName "the-hostname" -Restart
```

### Password not working after first boot
```bash
qm set <VMID> --cipassword 'YourPassword'
qm reboot <VMID>
```
