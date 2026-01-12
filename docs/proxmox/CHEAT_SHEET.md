:floppy_disk: Proxmox: Cheat Sheet
Cheat Sheet

TODO:

* GitHub Action Runners
* Terraform
* Ansible integration
* Ceph

Base VMs

Windows Server 2025

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
 # Assign a GPU for now - we'll remove it before creating a template
 --hostpci0 5a:00,pcie=1,rombar=0 

Windows 11

qm create 8000 \
--name "win11-work-base" \
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
--tpmstate0 local-lvm:1,version=v2.0 \
--ide2 local:iso/Win11_24H2_English_x64.iso,media=cdrom \
--ide3 local:iso/virtio-win-0.1.271.iso,media=cdrom \
--boot "order=ide2;scsi0" \
--hostpci0 5d:00,pcie=1,rombar=0

Assign a GPU to a VM

qm set 100 --hostpci0 5a:00,pcie=1,rombar=0


Use VirtIO-GPU Display

qm set 100 --display virtio

