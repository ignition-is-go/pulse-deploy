# MSN2700 Switch OS: SONiC to Fedora + mlxsw switchdev

## Problem

SONiC uses SAI/syncd, not the `mlxsw_spectrum` switchdev driver. Kernel bridge MDB entries are never offloaded to the Spectrum-1 ASIC — the switch floods all multicast to all VLAN ports regardless of IGMP snooping config. OVS per-VF snooping on Proxmox hosts mitigates this but doesn't solve switch-level flooding.

## Solution

Replace SONiC with **Fedora via ONIE** using the upstream `mlxsw_spectrum` switchdev driver. This driver implements `switchdev_obj_port_mdb`, which offloads bridge MDB entries directly to the Spectrum ASIC — confirmed up to 6992 entries.

### Why Fedora over Debian

- Debian's stock kernel has `CONFIG_MLXSW_CORE` disabled — requires custom kernel compile
- Fedora has shipped `CONFIG_MLXSW_SPECTRUM=m` since 2016 (kernel 4.4)
- Mellanox's own mlxsw wiki and ONIE installer target Fedora
- Prebuilt kernel = no ongoing kernel maintenance burden

### Why not DENT OS / Cumulus

- DENT: smaller community, adds NOS abstractions we don't need for flat L2
- Cumulus: requires per-switch license for production use, Spectrum-1 support unclear in 5.x

## Hardware

- **Switch**: Mellanox MSN2700-CS2FO (Spectrum-1, 32x QSFP28 100G)
- **ASIC**: Spectrum-1
- **CPU**: AMD64, mSATA boot disk, 2x e1000 management NICs
- **Console**: RJ45 serial, 115200n8
- **Current OS**: SONiC 202511

## Install Plan

Follows the [mlxsw wiki Installation guide](https://github.com/Mellanox/mlxsw/wiki/Installation).

### Phase 1: Prep

Download from `http://switchdev.mellanox.com/releases/`:
- [ ] `Fedora-ONIE-installer.bin`
- [ ] `install-onie.ks` (kickstart file)
- [ ] Fedora ISO image (matching version)

Stage on pulse-admin as an HTTP server:
- [ ] Mount the ISO and copy contents to serve directory:
  ```bash
  mkdir -p /srv/onie/{ks,iso}
  mount -o loop,ro -t iso9660 Fedora-*.iso /srv/onie/iso
  cp -r /srv/onie/iso /srv/onie/fedora
  umount /srv/onie/iso
  cp Fedora-ONIE-installer.bin /srv/onie/
  cp install-onie.ks /srv/onie/ks/
  ```
- [ ] Edit `install-onie.ks`: set `url` to point at `/srv/onie/fedora`, change `rootpw`
- [ ] Directory structure on HTTP server:
  ```
  /srv/onie/
  ├── Fedora-ONIE-installer.bin
  ├── ks/
  │   └── install-onie.ks
  └── fedora/
      └── (extracted ISO contents)
  ```
- [ ] Serve via `python3 -m http.server 8080 -d /srv/onie` or nginx
- [ ] Back up current SONiC config (`/etc/sonic/` — CoPP, interfaces, etc.)
- [ ] Document current switch port assignments and VLAN config

Default credentials after install — **root / switchdevftw** (change in kickstart before installing).

### Phase 2: Install

- [ ] Connect serial console to switch (115200n8)
- [ ] Reboot switch, select **ONIE: Rescue** from GRUB menu
- [ ] Run from ONIE prompt:
  ```bash
  onie-nos-install http://192.168.1.30:8080/Fedora-ONIE-installer.bin
  ```
- [ ] Installation proceeds automatically, reboots into Fedora
- [ ] Verify driver loaded:
  ```bash
  lsmod | grep mlxsw
  # Expect: mlxsw_spectrum, mlxsw_pci, mlxsw_core
  ```
- [ ] Query ASIC revision:
  ```bash
  devlink dev info pci/0000:03:00.0
  ```
- [ ] Update packages and install tools:
  ```bash
  dnf upgrade
  dnf install iproute-tc bridge-utils lm-sensors teamd
  ```
- [ ] Verify fans/thermals: `sensors`

### Phase 3: Port and Network Config

- [ ] Add udev rules for physical port naming (from [IPng Networks article](https://ipng.ch/s/articles/2023/11/11/debian-on-mellanox-sn2700-32x100g/), not in mlxsw wiki):
  ```bash
  cat << 'EOF' > /etc/udev/rules.d/10-local.rules
  SUBSYSTEM=="net", ACTION=="add", DRIVERS=="mlxsw_spectrum*", \
      NAME="sw$attr{phys_port_name}"
  EOF
  ```
  Ports appear as `swp1`–`swp32` after reboot.
- [ ] Configure management IP on e1000 NIC (192.168.1.5)
- [ ] Configure VLAN 20 media bridge with IGMP snooping:
  ```bash
  ip link add br0 type bridge vlan_filtering 1 mcast_snooping 1 mcast_igmp_version 3
  # Add trunk ports
  ip link set swp<N> master br0
  ip link set swp<N> up
  ip link set br0 up
  ```
- [ ] Verify MDB offload: `bridge mdb show` — entries should show `offload` flag
- [ ] Test multicast traffic is NOT flooded to non-member ports

### Phase 4: Ansible Integration

- [ ] Update `inventories/hrlv-dev/hosts.yml` — switch connection vars (SSH, not SONiC API)
- [ ] Decide on config management approach: Ansible roles for bridge/VLAN config vs. manual
- [ ] Remove `sonic_mcast` role dependency (CoPP IGMP trap no longer needed)

## Rollback

ONIE is preserved on the mSATA. To revert:
1. Reboot, select **ONIE: Uninstall OS** from GRUB
2. Re-enter ONIE install mode
3. Reinstall SONiC image

## References

- [mlxsw Wiki - Installation (Fedora ONIE)](https://github.com/Mellanox/mlxsw/wiki/Installation)
- [mlxsw Wiki - Bridge (MDB offload)](https://github.com/Mellanox/mlxsw/wiki/Bridge)
- [mlxsw Wiki - Multicast Routing](https://github.com/Mellanox/mlxsw/wiki/Multicast-Routing)
- [mlxsw Wiki - Installing a New Kernel](https://github.com/Mellanox/mlxsw/wiki/Installing-a-New-Kernel)
- [IPng Networks - Debian on SN2700](https://ipng.ch/s/articles/2023/11/11/debian-on-mellanox-sn2700-32x100g/)
- [Fedora kernel mlxsw patch (2016)](https://lists.fedoraproject.org/archives/list/kernel@lists.fedoraproject.org/thread/MM5HTUWLRNKLK23F4WV7HE2MTCDT262H/)
- [Linux bridge mailing list - switchdev MDB support](https://www.mail-archive.com/bridge@lists.linux-foundation.org/msg11123.html)
