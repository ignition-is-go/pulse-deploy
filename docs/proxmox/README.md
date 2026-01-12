# Proxmox Configuration Notes

## PVE Helper Scripts

Deploy the [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE) LXC container for a local web UI to run common Proxmox scripts:

```bash
bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/ct/pve-scripts-local.sh)"
```

After deploying a new Proxmox host, run the **Proxmox VE Post Install** script to configure free repos. If single-node, disable HA and Corosync.

## Documents

| Document | Description |
|----------|-------------|
| [GPU_PASSTHROUGH.md](GPU_PASSTHROUGH.md) | BIOS setup, IOMMU, VFIO configuration for RTX 6000 Ada |
| [CONNECTX6_SRIOV.md](CONNECTX6_SRIOV.md) | Mellanox firmware, SR-IOV VFs, OVS switchdev setup |
| [UBUNTU_SERVER_SETUP.md](UBUNTU_SERVER_SETUP.md) | Ubuntu VM configuration notes |
| [WINDOWS_GOLDEN_IMAGE.md](WINDOWS_GOLDEN_IMAGE.md) | Windows Server/11 VM templates |
| [CHEAT_SHEET.md](CHEAT_SHEET.md) | Quick reference commands |

## Hardware Summary

- **Server**: Gigabyte G493-ZB1-AAP1
- **Motherboard**: MZB3-G41-000 (BIOS R02_F24)
- **GPUs**: 8x NVIDIA RTX 6000 Ada (10de:26b1)
- **NICs**: 2x Mellanox ConnectX-6 MCX654106A-HCA_Ax (dual-port QSFP56)

## Key Configuration Points

### BIOS
- SVM Mode: Enabled
- IOMMU: Enabled

### Host Kernel
```
GRUB_CMDLINE_LINUX_DEFAULT="amd_iommu=on iommu=pt"
```

### VFIO for GPUs
```bash
# /etc/modprobe.d/vfio.conf
options vfio-pci ids=10de:26b1,10de:22ba
```

### ConnectX-6 SR-IOV
- Firmware: Ethernet mode, SRIOV_EN=1, NUM_OF_VFS=8
- Host: Switchdev mode via udev, OVS with hw-offload
- VFs passed through to VMs for RDMA/GPUDirect