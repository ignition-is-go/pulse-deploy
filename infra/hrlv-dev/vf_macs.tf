# -----------------------------------------------------------------------------
# VF MAC addresses — deterministic MACs for CX6/BF2 VF passthrough
#
# MAC scheme: 02:00:00:{vmid_hi}:{vmid_lo}:{purpose}
#   purpose 00 = ST 2110 (media), 01 = SMB (storage)
#
# Set on the Proxmox host via ip link set before VM start so the guest
# driver sees a known MAC address for explicit adapter identification.
# -----------------------------------------------------------------------------

locals {
  # All VMs with VF passthrough (Windows + Linux)
  all_vf_vms = {
    for vm_name, vm in merge(local.windows_gpu_vms, local.windows_vms, local.linux_gpu_vms) :
    vm_name => vm
    if length(vm.cx6_vf_offsets) > 0
  }

  # Per-VM MAC addresses (for ansible_host vars)
  # 2110 MAC = first VF (only for VMs that have ip_2110)
  vm_mac_2110 = {
    for vm_name, vm in local.all_vf_vms :
    vm_name => format("02:00:00:%02x:%02x:00", floor(vm.id / 256), vm.id % 256)
    if try(vm.ip_2110, null) != null
  }

  # SMB MAC = second VF when 2110 is present, first VF when SMB-only
  vm_mac_smb = {
    for vm_name, vm in local.all_vf_vms :
    vm_name => format("02:00:00:%02x:%02x:01", floor(vm.id / 256), vm.id % 256)
    if try(vm.ip_smb, null) != null
  }

  # Per-host VF MAC assignments (for Proxmox ansible_host vars)
  # List of {vf_pci, mac} per Proxmox node
  # Purpose byte: 00 = 2110, 01 = SMB. For single-VF VMs the purpose is
  # unambiguous (ip_2110 → 00, ip_smb → 01). Multi-VF uses index order.
  vf_mac_assignments = flatten([
    for vm_name, vm in local.all_vf_vms : [
      for i, offset in vm.cx6_vf_offsets : {
        node   = vm.node
        vf_pci = var.proxmox_hosts[vm.node].cx6_vfs[vm.cx6_card * local.cx6_vfs_per_card[vm.node] + offset]
        mac = format("02:00:00:%02x:%02x:%02x",
          floor(vm.id / 256), vm.id % 256,
          length(vm.cx6_vf_offsets) == 1 && try(vm.ip_smb, null) != null ? 1 : i
        )
      }
    ]
  ])

  vf_macs_by_host = {
    for node_name, _ in var.proxmox_hosts : node_name => [
      for a in local.vf_mac_assignments : {
        vf_pci = a.vf_pci
        mac    = a.mac
      } if a.node == node_name
    ]
  }
}
