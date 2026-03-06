# BlueField-2 SR-IOV VF Setup

BF2-only path extracted from [connectx6-sriov.md](connectx6-sriov.md).
No IB→ETH, no switchdev/udev, no OVS bonding — just firmware + systemd.

## Setup

```bash
# 1. Install firmware tools
apt-get install -y gcc make dkms pve-headers-$(uname -r)
mkdir -p /opt/installers/{mlxup,mft}

cd /opt/installers/mlxup
wget https://www.mellanox.com/downloads/firmware/mlxup/4.30.0/SFX/linux_x64/mlxup
chmod +x mlxup && ./mlxup

cd /opt/installers/mft
wget https://www.mellanox.com/downloads/MFT/mft-4.34.0-145-x86_64-deb.tgz
tar -xzf mft-4.34.0-145-x86_64-deb.tgz && cd mft-4.34.0-145-x86_64-deb && ./install.sh

# 2. Enable SR-IOV + VPD passthrough in firmware
mst start && mst status            # note device path, e.g. /dev/mst/mt41686_pciconf0
mlxconfig -d /dev/mst/mt41686_pciconf0 set SRIOV_EN=1
mlxconfig -d /dev/mst/mt41686_pciconf0 set VF_VPD_ENABLE=1   # needed for Rivermax licensing
reboot

# 3. Find the BF2 PCI address and interface name
lspci -nn | grep Mellanox            # note the BlueField-2 address, e.g. 41:00.0
ls -la /sys/class/net/*/device | grep 41:00   # gives the iface name, e.g. nic3

# 4. Create systemd service for runtime VF creation (replace nic3 with iface from step 3)
cat > /etc/systemd/system/bluefield-vfs.service << 'EOF'
[Unit]
Description=Enable BlueField-2 SR-IOV VFs
After=network-pre.target
Before=network.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo 8 > /sys/class/net/nic3/device/sriov_numvfs'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl enable --now bluefield-vfs.service

# 5. Verify — 8 VFs should appear
lspci | grep -i mellanox
```

VFs land at `PCI.2` through `PCI.7`, then `PCI+1.0`, `PCI+1.1`.
Update `cx6_vfs` in `terraform.tfvars` and add Proxmox resource mappings.

## Host reference

| Host | BF2 PCI | Interface | VF range |
|---|---|---|---|
| nyc-dev-pve-03 | 81:00.0 | nic3 | 81:00.2 — 81:01.1 |
| nyc-dev-pve-02 | 41:00.0 | nic3 | 41:00.2 — 41:01.1 |
| nyc-prod-pve-01 | — | — | no BF2, uses 2x standalone CX6 (5a:00/df:00) |
| nyc-prod-pve-02 | — | — | no BF2, uses 2x standalone CX6 (5a:00/df:00) |
