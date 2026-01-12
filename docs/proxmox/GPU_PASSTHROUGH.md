:floppy_disk:  Proxmox: GPU Passthrough
OS Setup



* Boot drive tools
    * Rufus forces DD mode for iso setup, and does not work
    * balenaEtcher does not force DD mode, and works

BIOS Setup


GIGABYTE G493-ZB1-AAP1
https://www.gigabyte.com/us/Enterprise/GPU-Server/G493-ZB1-AAP1-rev-3x

Motherboard: MZB3-G41-000
Version: R02_F24

* Advanced
    * CPU Configuration
        * SVM Mode [Enabled]
* AMD CBS
    * NBIO Common Options
        * IOMMU/Security
            * IOMMU [Enabled]

Proxmox Host Setup

Enable IOMMU in GRUB

Edit the GRUB configuration:

nano /etc/default/grub

Modify the GRUB_CMDLINE_LINUX_DEFAULT line:

GRUB_CMDLINE_LINUX_DEFAULT="amd_iommu=on iommu=pt"

Update GRUB and reboot:

update-grub
reboot

Verify IOMMU is working:

journalctl -b 0 | grep -i iommu

You should see output like:

Aug 13 17:17:15 nyc-prod-pve-01 kernel: Command line: BOOT_IMAGE=/boot/vmlinuz-6.14.8-2-pve root=/dev/mapper/pve-root ro amd_iommu=on iommu=pt
Aug 13 17:17:15 nyc-prod-pve-01 kernel: Kernel command line: BOOT_IMAGE=/boot/vmlinuz-6.14.8-2-pve root=/dev/mapper/pve-root ro amd_iommu=on iommu=pt
Aug 13 17:17:15 nyc-prod-pve-01 kernel: iommu: Default domain type: Passthrough (set via kernel command line)
Aug 13 17:17:15 nyc-prod-pve-01 kernel: pci 0000:74:00.2: AMD-Vi: IOMMU performance counters supported
Aug 13 17:17:15 nyc-prod-pve-01 kernel: platform AMDI0096:00: Adding to iommu group 0
Aug 13 17:17:15 nyc-prod-pve-01 kernel: pci 0000:74:00.3: Adding to iommu group 1
Aug 13 17:17:15 nyc-prod-pve-01 kernel: pci 0000:74:01.0: Adding to iommu group 2

Claude is very impressed with our grouping:


* Enterprise-level IOMMU grouping: You have 165+ IOMMU groups - this is exceptional! Most consumer boards have terrible grouping, but your server has nearly perfect isolation. 


Load VFIO Modules:

echo "vfio" > /etc/modules-load.d/vfio.conf 
echo "vfio_iommu_type1" >> /etc/modules-load.d/vfio.conf 
echo "vfio_pci" >> /etc/modules-load.d/vfio.conf

Update initramfs:

 update-initramfs -u

Find NVIDIA GPUs:

root@nyc-prod-pve-01:~# lspci -nn | grep -i nvidia
5a:00.0 VGA compatible controller [0300]: NVIDIA Corporation AD102GL [RTX 6000 Ada Generation] [10de:26b1] (rev a1)
5a:00.1 Audio device [0403]: NVIDIA Corporation AD102 High Definition Audio Controller [10de:22ba] (rev a1)
5d:00.0 VGA compatible controller [0300]: NVIDIA Corporation AD102GL [RTX 6000 Ada Generation] [10de:26b1] (rev a1)
5d:00.1 Audio device [0403]: NVIDIA Corporation AD102 High Definition Audio Controller [10de:22ba] (rev a1)
62:00.0 VGA compatible controller [0300]: NVIDIA Corporation AD102GL [RTX 6000 Ada Generation] [10de:26b1] (rev a1)
62:00.1 Audio device [0403]: NVIDIA Corporation AD102 High Definition Audio Controller [10de:22ba] (rev a1)
63:00.0 VGA compatible controller [0300]: NVIDIA Corporation AD102GL [RTX 6000 Ada Generation] [10de:26b1] (rev a1)
63:00.1 Audio device [0403]: NVIDIA Corporation AD102 High Definition Audio Controller [10de:22ba] (rev a1)
d8:00.0 VGA compatible controller [0300]: NVIDIA Corporation AD102GL [RTX 6000 Ada Generation] [10de:26b1] (rev a1)
d8:00.1 Audio device [0403]: NVIDIA Corporation AD102 High Definition Audio Controller [10de:22ba] (rev a1)
d9:00.0 VGA compatible controller [0300]: NVIDIA Corporation AD102GL [RTX 6000 Ada Generation] [10de:26b1] (rev a1)
d9:00.1 Audio device [0403]: NVIDIA Corporation AD102 High Definition Audio Controller [10de:22ba] (rev a1)
dc:00.0 VGA compatible controller [0300]: NVIDIA Corporation AD102GL [RTX 6000 Ada Generation] [10de:26b1] (rev a1)
dc:00.1 Audio device [0403]: NVIDIA Corporation AD102 High Definition Audio Controller [10de:22ba] (rev a1)
e2:00.0 VGA compatible controller [0300]: NVIDIA Corporation AD102GL [RTX 6000 Ada Generation] [10de:26b1] (rev a1)
e2:00.1 Audio device [0403]: NVIDIA Corporation AD102 High Definition Audio Controller [10de:22ba] (rev a1)

Note the Vendor IDs in [brackets]  e.g. 10de:22ba  and 10de:26b1

Configure VFIO to claim all GPUs:

echo "options vfio-pci ids=10de:26b1,10de:22ba" > /etc/modprobe.d/vfio.conf

(replace the ids with yours)

Blacklist NVIDIA drivers so the host doesn't claim the GPUs:

echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf  
echo "blacklist nvidiafb" >> /etc/modprobe.d/blacklist.conf

Reboot:

reboot

Verify VFIO configuration:

lspci -k | grep -A 3 -i nvidia
# Should show: Kernel driver in use: vfio-pci
5a:00.0 VGA compatible controller: NVIDIA Corporation AD102GL [RTX 6000 Ada Generation] (rev a1)
        Subsystem: NVIDIA Corporation Device 16a1
        Kernel driver in use: vfio-pci
        Kernel modules: nvidiafb, nouveau
5a:00.1 Audio device: NVIDIA Corporation AD102 High Definition Audio Controller (rev a1)
        Subsystem: NVIDIA Corporation Device 16a1
        Kernel driver in use: vfio-pci
        Kernel modules: snd_hda_intel
5b:00.0 PCI bridge: Broadcom / LSI PEX890xx PCIe Gen 5 Switch (rev b0)
--

