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
  # Per-VM MAC addresses (for Windows ansible_host vars)
  vm_mac_2110 = {
    for vm_name, vm in local.windows_gpu_vms :
    vm_name => format("02:00:00:%02x:%02x:00", floor(vm.id / 256), vm.id % 256)
    if length(vm.cx6_vf_offsets) > 0
  }

  vm_mac_smb = {
    for vm_name, vm in local.windows_gpu_vms :
    vm_name => format("02:00:00:%02x:%02x:01", floor(vm.id / 256), vm.id % 256)
    if length(vm.cx6_vf_offsets) > 1
  }

  # Per-host VF MAC assignments (for Proxmox ansible_host vars)
  # List of {vf_pci, mac} per Proxmox node
  vf_mac_assignments = flatten([
    for vm_name, vm in local.windows_gpu_vms : [
      for i, offset in vm.cx6_vf_offsets : {
        node   = vm.node
        vf_pci = var.proxmox_hosts[vm.node].cx6_vfs[vm.cx6_card * local.cx6_vfs_per_card[vm.node] + offset]
        mac    = format("02:00:00:%02x:%02x:%02x", floor(vm.id / 256), vm.id % 256, i)
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
