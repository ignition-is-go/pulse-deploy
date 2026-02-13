:floppy_disk: Proxmox: ConnectX-6 SR-IOV VFsMostly taken from this guide with some added steps:
https://dev.to/sergelogvinov/network-performance-optimization-with-nvidia-connectx-on-proxmox-5f7j
NOTE: this tutorial assumes various ConnectX-6 firmware configurations are already set - if not, the udev rules will silently fail to execute

There is also this NVIDA guide:
https://docs.nvidia.com/doca/archive/2-9-2/single+root+io+virtualization+(sr-iov)/index.html

NOTE: configuring ovs for LACP bonding requires setting up a PortChannel in the mellanox switch

Host setup

Install mlxup to update firmware
https://network.nvidia.com/support/firmware/mlxup-mft/

# Create your installer archive
mkdir -p /opt/installers/mlxup
cd /opt/installers/mlxup

# Download mlxup
wget https://www.mellanox.com/downloads/firmware/mlxup/4.30.0/SFX/linux_x64/mlxup

# Make executable
chmod +x mlxup

# Run
./mlxup

Reboot

reboot

View network adapters

root@nyc-prod-pve-01:~# lspci -nn | grep Mellanox
0f:00.0 Infiniband controller [0207]: Mellanox Technologies MT28908 Family [ConnectX-6] [15b3:101b]
0f:00.1 Infiniband controller [0207]: Mellanox Technologies MT28908 Family [ConnectX-6] [15b3:101b]
92:00.0 Infiniband controller [0207]: Mellanox Technologies MT28908 Family [ConnectX-6] [15b3:101b]
92:00.1 Infiniband controller [0207]: Mellanox Technologies MT28908 Family [ConnectX-6] [15b3:101b]
e1:00.0 Ethernet controller [0200]: Mellanox Technologies MT42822 BlueField-2 integrated ConnectX-6 Dx network controller [15b3:a2d6] (rev 01)
e1:00.1 DMA controller [0801]: Mellanox Technologies MT42822 BlueField-2 SoC Management Interface [15b3:c2d3] (rev 01)

Install MFT to configure firmware
https://network.nvidia.com/products/adapter-software/firmware-tools/

Create installer archive, download MFT, extract and install

mkdir -p /opt/installers/mft
cd /opt/installers/mft
wget https://www.mellanox.com/downloads/MFT/mft-4.34.0-145-x86_64-deb.tgz
tar -xzf mft-4.34.0-145-x86_64-deb.tgz
cd mft-4.34.0-145-x86_64-deb
./install.sh

MFT requires some pve-specific package dependencies to install

apt-get update
apt-get install -y gcc make dkms pve-headers-$(uname -r)

NOTE: if apt fails you likely need to configure non-subscription repositories: https://pve.proxmox.com/wiki/Package_Repositories

Start mst 

mst start

Output

root@nyc-prod-pve-01:/opt/installers/mft/mft-4.30.1-1210-x86_64-deb# mst start
Starting MST (Mellanox Software Tools) driver set
Loading MST PCI module - Success
Loading MST PCI configuration module - Success
Create devices
Unloading MST PCI module (unused) - Success

Check status

mst status

Output

root@nyc-prod-pve-01:/opt/installers/mft/mft-4.30.1-1210-x86_64-deb# mst status
MST modules:
------------
    MST PCI module is not loaded
    MST PCI configuration module loaded

MST devices:
------------
/dev/mst/mt4123_pciconf0         - PCI configuration cycles access.
                                   domain:bus:dev.fn=0000:0f:00.0 addr.reg=88 data.reg=92 cr_bar.gw_offset=-1
                                   Chip revision is: 00
/dev/mst/mt4123_pciconf1         - PCI configuration cycles access.
                                   domain:bus:dev.fn=0000:92:00.0 addr.reg=88 data.reg=92 cr_bar.gw_offset=-1
                                   Chip revision is: 00
/dev/mst/mt41686_pciconf0        - PCI configuration cycles access.
                                   domain:bus:dev.fn=0000:e1:00.0 addr.reg=88 data.reg=92 cr_bar.gw_offset=-1
                                   Chip revision is: 01

Check if adapters are currently in InfiniBand mode

mlxconfig -d /dev/mst/mt4123_pciconf0 query | grep LINK_TYPE

Output

root@nyc-prod-pve-01:/opt/installers/mft/mft-4.30.1-1210-x86_64-deb# mlxconfig -d /dev/mst/mt4123_pciconf0 query | grep LINK_TYPE
        LINK_TYPE_P1                                IB(1)
        LINK_TYPE_P2                                IB(1)
root@nyc-prod-pve-01:/opt/installers/mft/mft-4.30.1-1210-x86_64-deb# mlxconfig -d /dev/mst/mt4123_pciconf1 query | grep LINK_TYPE
        LINK_TYPE_P1                                IB(1)
        LINK_TYPE_P2                                IB(1)

NOTE: BlueField2 with integrated ConnectX-6 is Ethernet-only so this command will return nothing, you can skip this step

If IB(1) set ConnectX-6 to ethernet mode

mlxconfig -d /dev/mst/mt4123_pciconf0 set LINK_TYPE_P1=2 LINK_TYPE_P2=2

Output

root@nyc-prod-pve-01:/opt/installers/mft/mft-4.30.1-1210-x86_64-deb# mlxconfig -d /dev/mst/mt4123_pciconf0 set LINK_TYPE_P1=2 LINK_TYPE_P2=2

Device #1:
----------

Device type:        ConnectX6
Name:               MCX654106A-HCA_Ax
Description:        ConnectX-6 VPI adapter card; HDR IB (200Gb/s) and 200GbE; dual-port QSFP56; Socket Direct 2x PCIe3.0 x16; tall bracket; ROHS R6
Device:             /dev/mst/mt4123_pciconf0

Configurations:                                          Next Boot       New
        LINK_TYPE_P1                                IB(1)                ETH(2)
        LINK_TYPE_P2                                IB(1)                ETH(2)

 Apply new Configuration? (y/n) [n] : y
Applying... Done!
-I- Please reboot machine to load new configurations.

And the other card

mlxconfig -d /dev/mst/mt4123_pciconf1 set LINK_TYPE_P1=2 LINK_TYPE_P2=2

Output

root@nyc-prod-pve-01:/opt/installers/mft/mft-4.30.1-1210-x86_64-deb# mlxconfig -d /dev/mst/mt4123_pciconf1 set LINK_TYPE_P1=2 LINK_TYPE_P2=2

Device #1:
----------

Device type:        ConnectX6
Name:               MCX654106A-HCA_Ax
Description:        ConnectX-6 VPI adapter card; HDR IB (200Gb/s) and 200GbE; dual-port QSFP56; Socket Direct 2x PCIe3.0 x16; tall bracket; ROHS R6
Device:             /dev/mst/mt4123_pciconf1

Configurations:                                          Next Boot       New
        LINK_TYPE_P1                                IB(1)                ETH(2)
        LINK_TYPE_P2                                IB(1)                ETH(2)

 Apply new Configuration? (y/n) [n] : y
Applying... Done!
-I- Please reboot machine to load new configurations.

Set ConnectX-6 to SR-IOV enabled

mlxconfig -d /dev/mst/mt4123_pciconf0 set SRIOV_EN=1

Output

root@nyc-prod-pve-01:~# mlxconfig -d /dev/mst/mt4123_pciconf0 set SRIOV_EN=1

Device #1:
----------

Device type:        ConnectX6
Name:               MCX654106A-HCA_Ax
Description:        ConnectX-6 VPI adapter card; HDR IB (200Gb/s) and 200GbE; dual-port QSFP56; Socket Direct 2x PCIe3.0 x16; tall bracket; ROHS R6
Device:             /dev/mst/mt4123_pciconf0

Configurations:                                          Next Boot       New
        SRIOV_EN                                    False(0)             True(1)

 Apply new Configuration? (y/n) [n] : y
Applying... Done!
-I- Please reboot machine to load new configurations.
root@nyc-prod-pve-01:~# mlxconfig -d /dev/mst/mt4123_pciconf1 set SRIOV_EN=1

Device #1:
----------

Device type:        ConnectX6
Name:               MCX654106A-HCA_Ax
Description:        ConnectX-6 VPI adapter card; HDR IB (200Gb/s) and 200GbE; dual-port QSFP56; Socket Direct 2x PCIe3.0 x16; tall bracket; ROHS R6
Device:             /dev/mst/mt4123_pciconf1

Configurations:                                          Next Boot       New
        SRIOV_EN                                    False(0)             True(1)

 Apply new Configuration? (y/n) [n] : y
Applying... Done!
-I- Please reboot machine to load new configurations.

And the other

mlxconfig -d /dev/mst/mt4123_pciconf1 set SRIOV_EN=1

Output

root@nyc-prod-pve-01:~# mlxconfig -d /dev/mst/mt4123_pciconf1 set SRIOV_EN=1

Device #1:
----------

Device type:        ConnectX6
Name:               MCX654106A-HCA_Ax
Description:        ConnectX-6 VPI adapter card; HDR IB (200Gb/s) and 200GbE; dual-port QSFP56; Socket Direct 2x PCIe3.0 x16; tall bracket; ROHS R6
Device:             /dev/mst/mt4123_pciconf1

Configurations:                                          Next Boot       New
        SRIOV_EN                                    False(0)             True(1)

 Apply new Configuration? (y/n) [n] : y
Applying... Done!
-I- Please reboot machine to load new configurations.

NOTE: BlueField2 users resume here - BlueField2 requires enabling VFs at runtime so we create a service to make this persistent

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

Enable and start the service:

systemctl enable bluefield-vfs.service
 systemctl start bluefield-vfs.service 

Verify VFs created:

lspci | grep -i mellanox

Output

root@nyc-dev-pve-03:~# lspci | grep -i mellanox
81:00.0 Ethernet controller: Mellanox Technologies MT42822 BlueField-2 integrated ConnectX-6 Dx network controller (rev 01)
81:00.1 DMA controller: Mellanox Technologies MT42822 BlueField-2 SoC Management Interface (rev 01)
81:00.2 Ethernet controller: Mellanox Technologies ConnectX Family mlx5Gen Virtual Function (rev 01)
81:00.3 Ethernet controller: Mellanox Technologies ConnectX Family mlx5Gen Virtual Function (rev 01)
81:00.4 Ethernet controller: Mellanox Technologies ConnectX Family mlx5Gen Virtual Function (rev 01)
81:00.5 Ethernet controller: Mellanox Technologies ConnectX Family mlx5Gen Virtual Function (rev 01)
81:00.6 Ethernet controller: Mellanox Technologies ConnectX Family mlx5Gen Virtual Function (rev 01)
81:00.7 Ethernet controller: Mellanox Technologies ConnectX Family mlx5Gen Virtual Function (rev 01)
81:01.0 Ethernet controller: Mellanox Technologies ConnectX Family mlx5Gen Virtual Function (rev 01)
81:01.1 Ethernet controller: Mellanox Technologies ConnectX Family mlx5Gen Virtual Function (rev 01)

Verify new interfaces

ip link show

Output

root@nyc-dev-pve-03:~# ip link show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: nic1: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 9c:6b:00:74:dc:1c brd ff:ff:ff:ff:ff:ff
    altname enx9c6b0074dc1c
3: nic2: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 9c:6b:00:74:dc:1d brd ff:ff:ff:ff:ff:ff
    altname enx9c6b0074dc1d
4: nic3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq master vmbr0 state UP mode DEFAULT group default qlen 1000
    link/ether b8:ce:f6:bc:8a:6a brd ff:ff:ff:ff:ff:ff
    vf 0     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 1     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 2     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 3     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 4     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 5     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 6     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 7     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    altname enxb8cef6bc8a6a
5: nic0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 66:b7:8e:c1:a1:fb brd ff:ff:ff:ff:ff:ff
6: vmbr0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether b8:ce:f6:bc:8a:6a brd ff:ff:ff:ff:ff:ff
7: enp129s0f0v0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether c6:62:d3:71:6c:35 brd ff:ff:ff:ff:ff:ff
8: enp129s0f0v1: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 56:97:11:b6:59:a6 brd ff:ff:ff:ff:ff:ff
9: enp129s0f0v2: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 9a:19:96:9a:5e:0a brd ff:ff:ff:ff:ff:ff
10: enp129s0f0v3: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 8e:3d:05:b3:f8:28 brd ff:ff:ff:ff:ff:ff
11: enp129s0f0v4: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether e6:56:a7:76:2b:1a brd ff:ff:ff:ff:ff:ff
12: enp129s0f0v5: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 86:36:5a:3d:aa:a7 brd ff:ff:ff:ff:ff:ff
13: enp129s0f0v6: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether d2:84:71:5a:03:a7 brd ff:ff:ff:ff:ff:ff
14: enp129s0f0v7: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether e2:fe:0e:ed:f1:ce brd ff:ff:ff:ff:ff:ff

BlueField2 users can stop here and proceed directly to creating resource mappings for virtual functions

Back to ConnectX-6 users...
Set ConnectX-6 to have some number of VFs (in this case 8)

mlxconfig -d /dev/mst/mt4123_pciconf0 set NUM_OF_VFS=8

Output

root@nyc-prod-pve-01:~# mlxconfig -d /dev/mst/mt4123_pciconf0 set NUM_OF_VFS=8

Device #1:
----------

Device type:        ConnectX6
Name:               MCX654106A-HCA_Ax
Description:        ConnectX-6 VPI adapter card; HDR IB (200Gb/s) and 200GbE; dual-port QSFP56; Socket Direct 2x PCIe3.0 x16; tall bracket; ROHS R6
Device:             /dev/mst/mt4123_pciconf0

Configurations:                                          Next Boot       New
        NUM_OF_VFS                                  0                    8

 Apply new Configuration? (y/n) [n] : y
Applying... Done!
-I- Please reboot machine to load new configurations.
root@nyc-prod-pve-01:~# mlxconfig -d /dev/mst/mt4123_pciconf1 set NUM_OF_VFS=8

Device #1:
----------

Device type:        ConnectX6
Name:               MCX654106A-HCA_Ax
Description:        ConnectX-6 VPI adapter card; HDR IB (200Gb/s) and 200GbE; dual-port QSFP56; Socket Direct 2x PCIe3.0 x16; tall bracket; ROHS R6
Device:             /dev/mst/mt4123_pciconf1

Configurations:                                          Next Boot       New
        NUM_OF_VFS                                  0                    8

 Apply new Configuration? (y/n) [n] : y
Applying... Done!
-I- Please reboot machine to load new configurations.

Reboot

reboot

Confirm ConnectX-6 adapters are in ethernet mode

ip link show

Output

root@nyc-prod-pve-01:~# ip link show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eno1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq master vmbr0 state UP mode DEFAULT group default qlen 1000
    link/ether 10:ff:e0:06:2f:15 brd ff:ff:ff:ff:ff:ff
    altname enp71s0f0
    altname enx10ffe0062f15
3: eno2: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 10:ff:e0:06:2f:16 brd ff:ff:ff:ff:ff:ff
    altname enp71s0f1
    altname enx10ffe0062f16
4: ens13f0np0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 0c:42:a1:d2:03:5a brd ff:ff:ff:ff:ff:ff
    altname enp15s0f0np0
    altname enx0c42a1d2035a
5: ens13f1np1: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 0c:42:a1:d2:03:5b brd ff:ff:ff:ff:ff:ff
    altname enp15s0f1np1
    altname enx0c42a1d2035b
6: enp225s0f0np0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether b8:ce:f6:75:63:e4 brd ff:ff:ff:ff:ff:ff
    altname enxb8cef67563e4
7: enp146s0f0np0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether b8:ce:f6:a0:b2:8a brd ff:ff:ff:ff:ff:ff
    altname enxb8cef6a0b28a
8: enp146s0f1np1: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether b8:ce:f6:a0:b2:8b brd ff:ff:ff:ff:ff:ff
    altname enxb8cef6a0b28b
9: vmbr0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether 10:ff:e0:06:2f:15 brd ff:ff:ff:ff:ff:ff
10: veth101i0@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master vmbr0 state UP mode DEFAULT group default qlen 1000
    link/ether fe:0c:cc:af:f0:97 brd ff:ff:ff:ff:ff:ff link-netnsid 0
11: veth102i0@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master vmbr0 state UP mode DEFAULT group default qlen 1000
    link/ether fe:45:db:5e:9b:47 brd ff:ff:ff:ff:ff:ff link-netnsid 1
12: veth103i0@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master vmbr0 state UP mode DEFAULT group default qlen 1000
    link/ether fe:ca:ea:95:2e:e9 brd ff:ff:ff:ff:ff:ff link-netnsid 2
13: tap201i0: <BROADCAST,MULTICAST,PROMISC,UP,LOWER_UP> mtu 1500 qdisc fq_codel master vmbr0 state UNKNOWN mode DEFAULT group default qlen 1000
    link/ether c6:ac:d7:41:08:b1 brd ff:ff:ff:ff:ff:ff

Confirm these new interfaces are the Mellanox cards

root@nyc-prod-pve-01:~# ethtool -i ens13f0np0 | grep driver
driver: mlx5_core
root@nyc-prod-pve-01:~# ethtool -i enp146s0f0np0 | grep driver
driver: mlx5_core

Get the switchid values for each interface

root@nyc-prod-pve-01:~# ip -d link show ens13f0np0 | grep switchid
    link/ether 0c:42:a1:d2:03:5a brd ff:ff:ff:ff:ff:ff promiscuity 0 allmulti 0 minmtu 68 maxmtu 9978 addrgenmode eui64 numtxqueues 760 numrxqueues 63 gso_max_size 65536 gso_max_segs 65535 tso_max_size 524280 tso_max_segs 65535 gro_max_size 65536 gso_ipv4_max_size 65536 gro_ipv4_max_size 65536 portname p0 switchid 5a03d20003a1420c parentbus pci parentdev 0000:0f:00.0
root@nyc-prod-pve-01:~# ip -d link show enp146s0f0np0 | grep switchid
    link/ether b8:ce:f6:a0:b2:8a brd ff:ff:ff:ff:ff:ff promiscuity 0 allmulti 0 minmtu 68 maxmtu 9978 addrgenmode eui64 numtxqueues 760 numrxqueues 63 gso_max_size 65536 gso_max_segs 65535 tso_max_size 524280 tso_max_segs 65535 gro_max_size 65536 gso_ipv4_max_size 65536 gro_ipv4_max_size 65536 portname p0 switchid 8ab2a00003f6ceb8 parentbus pci parentdev 0000:92:00.0

Note the mapping

* ConnectX-6 #1 (0f:00.0): ens13f0np0 → switchid 5a03d20003a1420c
* ConnectX-6 #2 (92:00.0): enp146s0f0np0 → switchid 8ab2a00003f6ceb8


Install Open vSwitch

apt install openvswitch-switch ifupdown2 patch

Create udev rules

root@nyc-prod-pve-01:~# vi /etc/udev/rules.d/70-persistent-net-vf.rules
# ============================================================
# ConnectX-6 Adapter #1 (0f:00.0 and 0f:00.1)
# ============================================================
# Set to switchdev mode
KERNELS=="0000:0f:00.0", DRIVERS=="mlx5_core", SUBSYSTEMS=="pci", ACTION=="add", ATTR{sriov_totalvfs}=="?*", RUN+="/usr/sbin/devlink dev eswitch set pci/0000:0f:00.0 mode switchdev", ATTR{sriov_numvfs}="0"
KERNELS=="0000:0f:00.1", DRIVERS=="mlx5_core", SUBSYSTEMS=="pci", ACTION=="add", ATTR{sriov_totalvfs}=="?*", RUN+="/usr/sbin/devlink dev eswitch set pci/0000:0f:00.1 mode switchdev", ATTR{sriov_numvfs}="0"

# Create 8 VFs on first port
SUBSYSTEM=="net", ACTION=="add", ATTR{phys_switch_id}=="5a03d20003a1420c", ATTR{phys_port_name}=="p0", ATTR{device/sriov_totalvfs}=="?*", ATTR{device/sriov_numvfs}=="0", ATTR{device/sriov_numvfs}="8"

# Rename VFs to ovs-sw1pf0vf0 through ovs-sw1pf0vf7
SUBSYSTEM=="net", ACTION=="add", ATTR{phys_switch_id}=="5a03d20003a1420c", ATTR{phys_port_name}!="p[0-9]*", ATTR{phys_port_name}!="", NAME="ovs-sw1$attr{phys_port_name}"

# ============================================================
# ConnectX-6 Adapter #2 (92:00.0 and 92:00.1)
# ============================================================
# Set to switchdev mode
KERNELS=="0000:92:00.0", DRIVERS=="mlx5_core", SUBSYSTEMS=="pci", ACTION=="add", ATTR{sriov_totalvfs}=="?*", RUN+="/usr/sbin/devlink dev eswitch set pci/0000:92:00.0 mode switchdev", ATTR{sriov_numvfs}="0"
KERNELS=="0000:92:00.1", DRIVERS=="mlx5_core", SUBSYSTEMS=="pci", ACTION=="add", ATTR{sriov_totalvfs}=="?*", RUN+="/usr/sbin/devlink dev eswitch set pci/0000:92:00.1 mode switchdev", ATTR{sriov_numvfs}="0"

# Create 8 VFs on first port
SUBSYSTEM=="net", ACTION=="add", ATTR{phys_switch_id}=="8ab2a00003f6ceb8", ATTR{phys_port_name}=="p0", ATTR{device/sriov_totalvfs}=="?*", ATTR{device/sriov_numvfs}=="0", ATTR{device/sriov_numvfs}="8"

# Rename VFs to ovs-sw2pf0vf0 through ovs-sw2pf0vf7
SUBSYSTEM=="net", ACTION=="add", ATTR{phys_switch_id}=="8ab2a00003f6ceb8", ATTR{phys_port_name}!="p[0-9]*", ATTR{phys_port_name}!="", NAME="ovs-sw2$attr{phys_port_name}"

NOTE: The tutorial attempts to rename the interfaces but this gets overridden by a later rule, which I let stick:

root@nyc-prod-pve-01:~# udevadm test /sys/class/net/ens13f0r0 2>&1 | grep -i "NAME\|ovs"
Reading rules file: /usr/lib/udev/rules.d/73-special-net-names.rules
ens13f0r0: /etc/udev/rules.d/70-persistent-net-vf.rules:12 NAME 'ovs-sw1pf0vf0'
ens13f0r0: /usr/lib/udev/rules.d/70-virtual-function-pinning.rules:1 NAME ''
ens13f0r0: Device has name_assign_type=4
ens13f0r0: Policy *keep*: keeping existing userspace name

Therefore the VFs will be named ens13f0r0 through ens13f0r7 (instead of ovs-sw1pf0vf0 through ovs-sw1pf0vf7)  and enp146s0f0r0 through enp146s0f0r7 (instead of ovs-sw2pf0vf0 through ovs-sw2pf0vf7) 

Next disable auto update for openvswitch-switch package

root@nyc-prod-pve-01:~# apt-mark hold openvswitch-switch
openvswitch-switch set on hold.

Reboot

reboot

Configure ovs-vsctl

ovs-vsctl set Open_vSwitch . other_config:hw-offload=true
ovs-vsctl set Open_vSwitch . other_config:lacp-fallback-ab=true 
ovs-vsctl set Open_vSwitch . other_config:tc-policy=skip_sw


Verify openvswitch and adapter configuration

root@nyc-prod-pve-01:~# ovs-vsctl show
2aa59794-c7d0-4c19-ac95-d5a4e7dc5149
    ovs_version: "3.5.0"
root@nyc-prod-pve-01:~# ovs-vsctl get Open_vSwitch . other_config
{hw-offload="true", lacp-fallback-ab="true", tc-policy=skip_sw}
root@nyc-prod-pve-01:~# ip -d link show ens13f0np0
4: ens13f0np0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 0c:42:a1:d2:03:5a brd ff:ff:ff:ff:ff:ff promiscuity 0 allmulti 0 minmtu 68 maxmtu 9978 addrgenmode eui64 numtxqueues 760 numrxqueues 63 gso_max_size 65536 gso_max_segs 65535 tso_max_size 524280 tso_max_segs 65535 gro_max_size 65536 gso_ipv4_max_size 65536 gro_ipv4_max_size 65536 portname p0 switchid 5a03d20003a1420c parentbus pci parentdev 0000:0f:00.0
    vf 0     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 1     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 2     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 3     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 4     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 5     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 6     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 7     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    altname enp15s0f0np0
    altname enx0c42a1d2035a
root@nyc-prod-pve-01:~# ip -d link show enp146s0f0np0
7: enp146s0f0np0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether b8:ce:f6:a0:b2:8a brd ff:ff:ff:ff:ff:ff promiscuity 0 allmulti 0 minmtu 68 maxmtu 9978 addrgenmode eui64 numtxqueues 760 numrxqueues 63 gso_max_size 65536 gso_max_segs 65535 tso_max_size 524280 tso_max_segs 65535 gro_max_size 65536 gso_ipv4_max_size 65536 gro_ipv4_max_size 65536 portname p0 switchid 8ab2a00003f6ceb8 parentbus pci parentdev 0000:92:00.0
    vf 0     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 1     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 2     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 3     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 4     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 5     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 6     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    vf 7     link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff, spoof checking off, link-state auto, trust off, query_rss off
    altname enxb8cef6a0b28a

Verify switchdev mode

root@nyc-prod-pve-01:~# devlink dev eswitch show pci/0000:0f:00.0
pci/0000:0f:00.0: mode switchdev inline-mode none encap-mode basic
root@nyc-prod-pve-01:~# devlink dev eswitch show pci/0000:92:00.0
pci/0000:92:00.0: mode switchdev inline-mode none encap-mode basic

Configure the bond interfaces

root@nyc-prod-pve-01:~# vi /etc/network/interfaces
# ConnectX-6 Adapter #1 - Bonded Bridge
auto ens13f0np0
iface ens13f0np0 inet manual

auto ens13f1np1
iface ens13f1np1 inet manual

auto vmbr1
iface vmbr1 inet manual
    ovs_type OVSBridge
    ovs_ports bond1
    ovs_mtu 9000
    # No address

auto bond1
iface bond1 inet manual
    ovs_type OVSBond
    ovs_bonds ens13f0np0 ens13f1np1
    ovs_bridge vmbr1
    ovs_mtu 9000
    ovs_options lacp=active bond_mode=balance-tcp

# ConnectX-6 Adapter #2 - Bonded Bridge
auto enp146s0f0np0
iface enp146s0f0np0 inet manual

auto enp146s0f1np1
iface enp146s0f1np1 inet manual

auto vmbr2
iface vmbr2 inet manual
    ovs_type OVSBridge
    ovs_ports bond2
    ovs_mtu 9000
    # No address

auto bond2
iface bond2 inet manual
    ovs_type OVSBond
    ovs_bonds enp146s0f0np0 enp146s0f1np1
    ovs_bridge vmbr2
    ovs_mtu 9000
    ovs_options lacp=active bond_mode=balance-tcp

source /etc/network/interfaces.d/*

Reboot

reboot

Verify newly created interfaces

ip link show
43: vmbr1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9000 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/ether 0c:42:a1:d2:03:5a brd ff:ff:ff:ff:ff:ff
44: bond1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/ether a2:42:be:3c:77:b7 brd ff:ff:ff:ff:ff:ff
45: vmbr2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9000 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/ether b8:ce:f6:a0:b2:8a brd ff:ff:ff:ff:ff:ff
46: bond2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/ether 42:cb:61:b3:3c:ee brd ff:ff:ff:ff:ff:ff

NOTE: Here the tutorial says "Add the virtual functions to the Open vSwitch" but in fact we should add the representors

* The representors (ens13f0r0, which tutorial renames to ovs-sw1pf0vf0) get added to OVS
* The actual VFs (ens13f0v0, the PCI devices) get passed through to VMs later

root@nyc-prod-pve-01:~# vi /etc/network/interfaces.d/vmbr1-vfs.conf
# Add VF representors for ConnectX-6 Adapter #1 to vmbr1
auto ens13f0r0
iface ens13f0r0 inet manual
    ovs_type OVSPort
    ovs_bridge vmbr1
    ovs_mtu 9000

auto ens13f0r1
iface ens13f0r1 inet manual
    ovs_type OVSPort
    ovs_bridge vmbr1
    ovs_mtu 9000

auto ens13f0r2
iface ens13f0r2 inet manual
    ovs_type OVSPort
    ovs_bridge vmbr1
    ovs_mtu 9000

auto ens13f0r3
iface ens13f0r3 inet manual
    ovs_type OVSPort
    ovs_bridge vmbr1
    ovs_mtu 9000

auto ens13f0r4
iface ens13f0r4 inet manual
    ovs_type OVSPort
    ovs_bridge vmbr1
    ovs_mtu 9000

auto ens13f0r5
iface ens13f0r5 inet manual
    ovs_type OVSPort
    ovs_bridge vmbr1
    ovs_mtu 9000

auto ens13f0r6
iface ens13f0r6 inet manual
    ovs_type OVSPort
    ovs_bridge vmbr1
    ovs_mtu 9000

auto ens13f0r7
iface ens13f0r7 inet manual
    ovs_type OVSPort
    ovs_bridge vmbr1
    ovs_mtu 9000

And the other

root@nyc-prod-pve-01:~# vi /etc/network/interfaces.d/vmbr2-vfs.conf
# Add VF representors for ConnectX-6 Adapter #2 to vmbr2
auto enp146s0f0r0
iface enp146s0f0r0 inet manual
    ovs_type OVSPort
    ovs_bridge vmbr2
    ovs_mtu 9000

auto enp146s0f0r1
iface enp146s0f0r1 inet manual
    ovs_type OVSPort
    ovs_bridge vmbr2
    ovs_mtu 9000

auto enp146s0f0r2
iface enp146s0f0r2 inet manual
    ovs_type OVSPort
    ovs_bridge vmbr2
    ovs_mtu 9000

auto enp146s0f0r3
iface enp146s0f0r3 inet manual
    ovs_type OVSPort
    ovs_bridge vmbr2
    ovs_mtu 9000

auto enp146s0f0r4
iface enp146s0f0r4 inet manual
    ovs_type OVSPort
    ovs_bridge vmbr2
    ovs_mtu 9000

auto enp146s0f0r5
iface enp146s0f0r5 inet manual
    ovs_type OVSPort
    ovs_bridge vmbr2
    ovs_mtu 9000

auto enp146s0f0r6
iface enp146s0f0r6 inet manual
    ovs_type OVSPort
    ovs_bridge vmbr2
    ovs_mtu 9000

auto enp146s0f0r7
iface enp146s0f0r7 inet manual
    ovs_type OVSPort
    ovs_bridge vmbr2
    ovs_mtu 9000

Reboot

reboot

Verify OVS configuration

root@nyc-prod-pve-01:~# ip -d link show
...
11: ens13f0r1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9000 qdisc mq master ovs-system state UP mode DEFAULT group default qlen 1000
    link/ether 82:49:a9:62:52:6a brd ff:ff:ff:ff:ff:ff promiscuity 1 allmulti 0 minmtu 68 maxmtu 9978
    openvswitch_slave addrgenmode eui64 numtxqueues 63 numrxqueues 63 gso_max_size 65536 gso_max_segs 65535 tso_max_size 65536 tso_max_segs 65535 gro_max_size 65536 gso_ipv4_max_size 65536 gro_ipv4_max_size 65536 portname pf0vf1 switchid 5a03d20003a1420c parentbus pci parentdev 0000:0f:00.0
    altname enp15s0f0r1
12: enp146s0f0r1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9000 qdisc mq master ovs-system state UP mode DEFAULT group default qlen 1000
    link/ether 42:14:2c:10:53:2f brd ff:ff:ff:ff:ff:ff promiscuity 1 allmulti 0 minmtu 68 maxmtu 9978
    openvswitch_slave addrgenmode eui64 numtxqueues 63 numrxqueues 63 gso_max_size 65536 gso_max_segs 65535 tso_max_size 65536 tso_max_segs 65535 gro_max_size 65536 gso_ipv4_max_size 65536 gro_ipv4_max_size 65536 portname pf0vf1 switchid 8ab2a00003f6ceb8 parentbus pci parentdev 0000:92:00.0
...

As well as

root@nyc-prod-pve-01:~# ovs-vsctl show
cadf7b4b-d43e-440f-94bd-b80ffb7ae9d2
    Bridge vmbr2
        Port enp146s0f0r5
            Interface enp146s0f0r5
        Port enp146s0f0r2
            Interface enp146s0f0r2
        Port enp146s0f0r7
            Interface enp146s0f0r7
        Port vmbr2
            Interface vmbr2
                type: internal
        Port enp146s0f0r3
            Interface enp146s0f0r3
        Port enp146s0f0r0
            Interface enp146s0f0r0
        Port enp146s0f0r4
            Interface enp146s0f0r4
        Port enp146s0f0r6
            Interface enp146s0f0r6
        Port bond2
            Interface enp146s0f0np0
            Interface enp146s0f1np1
        Port enp146s0f0r1
            Interface enp146s0f0r1
    Bridge vmbr1
        Port ens13f0r3
            Interface ens13f0r3
        Port ens13f0r7
            Interface ens13f0r7
        Port vmbr1
            Interface vmbr1
                type: internal
        Port ens13f0r6
            Interface ens13f0r6
        Port ens13f0r0
            Interface ens13f0r0
        Port ens13f0r1
            Interface ens13f0r1
        Port bond1
            Interface ens13f1np1
            Interface ens13f0np0
        Port ens13f0r4
            Interface ens13f0r4
        Port ens13f0r5
            Interface ens13f0r5
        Port ens13f0r2
            Interface ens13f0r2
    ovs_version: "3.5.0"

Create a windows VM in proxmox, add the virtual function as a PCIe device, install windows drivers and and verify the ConnectX-6 appears in device manager
