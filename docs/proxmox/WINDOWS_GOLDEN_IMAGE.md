:floppy_disk: Proxmox: Windows Golden Image
Windows Golden Image

Windows VM Setup

CLI:

Create base VM:

# Create and configure Windows Server 2025 VM with GPU passthrough
qm create 9000 \
 --name "win-serv25-base" \
 --memory 16384 \
 --cores 8 \
 --sockets 1 \
 --cpu host \
 --machine q35 \
 --bios seabios \
 --ostype win11 \
 --agent 1 \
 --balloon 0 \
 --scsi0 ZFS-Data:100 \
 --scsihw virtio-scsi-pci \
 --net0 virtio,bridge=vmbr0 \
 --efidisk0 local-lvm:1 \
 --ide2 local:iso/26100.1742.240906-0331.ge_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso,media=cdrom \
 --ide3 local:iso/virtio-win-0.1.271.iso,media=cdrom \
 --boot "order=ide2;scsi0" \
 # Assign a GPU for now, but remove it before creating a template
 --hostpci0 5a:00,pcie=1,rombar=0 

Windows Installation

* Install now
* Windows Server 2025 Standard Evaluation (Desktop Experience)
* Accept license
* Select location to install Windows Server
    * Load Driver
        * virtio-win CD (should be D: or E:)
            * vioscsi → w11 → amd64
    * Select Disk 0 Unallocated Space
    * Next
* Administrator password setup

Post-Installation (GPU Workstation/Node)

* Install VirtIO drivers
    * https://pve.proxmox.com/wiki/Windows_VirtIO_Drivers
    * Windows Explorer → E:\virtio-win → virtio-win-gt-x64
    * Also run virtio-win-guest-tools.exe for QEMU Guest Agent and SPICE
* Install NVIDIA drivers
    * RTX 6000 Ada
* Reboot

Verify Device Manager Has Drivers


EDIDs

* NVIDIA Control Panel

https://lucidslack.slack.com/files/U055QMSP7FC/F09AEK0RS5S/4k_72hz.txt


Ubuntu VM

Download the Base Image

# SSH into Proxmox host
ssh root@nyc-prod-pve-01

# Go to ISO storage directory
cd /var/lib/vz/template/iso/

# Download Ubuntu 24.04 LTS Server ISO
wget "https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-live-server-amd64.iso" -O ubuntu-24.04.3-live-server-amd64.iso

# Verify download
ls -lah ubuntu-24.04.3-live-server-amd64.iso

Create the VM

qm create 300 \
  --name "ubuntu-24-server" \
  --memory 128000 \
  --cores 2 \
  --sockets 1 \
  --cpu host \
  --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-pci \
  --ostype l26
  
# Add a 512GB disk on ZFS storage
qm set 300 --scsi0 ZFS-Data:512

# Add the Ubuntu ISO as CD-ROM 
qm set 300 --ide2 local:iso/ubuntu-24.04.3-live-server-amd64.iso,media=cdrom

# Set boot order
qm set 300 --boot "order=ide2;scsi0"

# Enable QEMU Guest Agent
qm set 300 --agent enabled=1

Install Ubuntu

* lucid user

Disable systemd-networkd-wait-online

# Disable the wait-online service that hangs boot
sudo systemctl disable systemd-networkd-wait-online.service
sudo systemctl mask systemd-networkd-wait-online.service

Add a GPU

# In the proxmox host
qm stop 300

# Add GPU passthrough
qm set 300 --hostpci0 d8:00,pcie=1,rombar=0

# Set machine type to q35 (required for PCIe passthrough)
qm set 300 --machine q35

qm start 300

NVIDIA Drivers

# In the VM
sudo ubuntu-drivers install

Create Directory Structure on Proxmox Host

# SSH into your Proxmox host
ssh root@nyc-prod-pve-01
# Create directories for our GPU setup files
mkdir -p /var/lib/vz/snippets/{gpu-configs,scripts,drivers}

Download NVIDIA Drivers

cd tmp

# Download NVIDIA driver (you need to get the URL from NVIDIA's website)
# Go to: https://www.nvidia.com/Download/index.aspx
# Search: RTX 6000 Ada Generation, Windows Server 2022
# Follow the links
# Copy the 'Download' link address

 # Replace URL with the one you copied 
wget -O nvidia-rtx6000ada.exe "https://us.download.nvidia.com/Windows/Quadro_Certified/580.97/580.97-quadro-rtx-desktop-notebook-win10-win11-64bit-international-dch-whql.exe"

# Move to drivers directory
mv nvidia-rtx6000ada.exe /var/lib/vz/snippets/drivers/

Setup SMB Share

NOTE: If you run into signing errors with apt, comment out the lines in /etc/apt/sources.list.d/pve-enterprise.sources and /etc/apt/sources.list.d/ceph.sources

apt update
apt install samba samba-common-bin -y

# Verify installation
smbd --version

Create Share Directory Structure

# Create main directory for VM setup files
mkdir -p /srv/samba/vm-setup

# Create subdirectories
mkdir -p /srv/samba/vm-setup/drivers
mkdir -p /srv/samba/vm-setup/gpu-configs
mkdir -p /srv/samba/vm-setup/scripts

# Set permissions (everyone can read)
chmod -R 755 /srv/samba/vm-setup

# Check it was created
ls -la /srv/samba/

