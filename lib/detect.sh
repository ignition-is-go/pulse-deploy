#!/bin/bash
# lib/detect.sh - Hardware and interface detection utilities
# Usage: source "$REPO_ROOT/lib/detect.sh"
#
# This is a library file. Do not execute directly.

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: This script is a library and should be sourced, not executed" >&2
    exit 1
fi

#######################################
# Vendor IDs
#######################################
readonly MELLANOX_VENDOR_ID="0x15b3"
readonly INTEL_VENDOR_ID="0x8086"

#######################################
# Find interface by vendor ID
# Arguments:
#   vendor_id: PCI vendor ID (e.g., 0x15b3)
# Outputs:
#   Interface name to stdout
# Returns:
#   0 if found, 1 otherwise
#######################################
find_interface_by_vendor() {
    local vendor_id="$1"
    local iface name vendor

    for iface in /sys/class/net/*; do
        name=$(basename "$iface")
        [[ "$name" == "lo" ]] && continue

        local vendor_file="$iface/device/vendor"
        [[ -f "$vendor_file" ]] || continue

        vendor=$(cat "$vendor_file" 2>/dev/null) || continue
        if [[ "$vendor" == "$vendor_id" ]]; then
            echo "$name"
            return 0
        fi
    done
    return 1
}

#######################################
# Find Mellanox ConnectX interface
# Outputs:
#   Interface name to stdout
# Returns:
#   0 if found, 1 otherwise
#######################################
find_mellanox_interface() {
    find_interface_by_vendor "$MELLANOX_VENDOR_ID"
}

#######################################
# Find first interface with PTP hardware clock
# Outputs:
#   Interface name to stdout
# Returns:
#   0 if found, 1 otherwise
#######################################
find_ptp_capable_interface() {
    local iface name

    for iface in /sys/class/net/*; do
        name=$(basename "$iface")
        [[ "$name" == "lo" ]] && continue

        # Skip virtual interfaces
        case "$name" in
            docker*|veth*|br-*|virbr*|vnet*) continue ;;
        esac

        # Check for PTP hardware clock
        if ethtool -T "$name" 2>/dev/null | grep -q "PTP Hardware Clock: [0-9]"; then
            echo "$name"
            return 0
        fi
    done
    return 1
}

#######################################
# Get MAC address for interface
# Arguments:
#   interface: Network interface name
# Outputs:
#   MAC address in uppercase to stdout
# Returns:
#   0 if found, 1 otherwise
#######################################
get_mac_address() {
    local iface="$1"
    local mac_file="/sys/class/net/$iface/address"

    if [[ -f "$mac_file" ]]; then
        cat "$mac_file" | tr '[:lower:]' '[:upper:]'
        return 0
    fi
    return 1
}

#######################################
# Get PCI address for interface
# Arguments:
#   interface: Network interface name
# Outputs:
#   PCI address (e.g., 0000:02:00.0) to stdout
# Returns:
#   0 if found, 1 otherwise
#######################################
get_pci_address() {
    local iface="$1"
    local device_link="/sys/class/net/$iface/device"

    if [[ -L "$device_link" ]]; then
        basename "$(readlink -f "$device_link")"
        return 0
    fi
    return 1
}

#######################################
# Check if interface supports RDMA
# Arguments:
#   interface: Network interface name
# Returns:
#   0 if RDMA capable, 1 otherwise
#######################################
has_rdma_support() {
    local iface="$1"

    # Check for RDMA device in sysfs
    local pci_addr
    pci_addr=$(get_pci_address "$iface") || return 1

    # Look for infiniband or RDMA device
    if [[ -d "/sys/class/infiniband" ]]; then
        for rdma_dev in /sys/class/infiniband/*; do
            [[ -d "$rdma_dev" ]] || continue
            if readlink -f "$rdma_dev/device" | grep -q "$pci_addr"; then
                return 0
            fi
        done
    fi
    return 1
}

#######################################
# Get RDMA device name for interface
# Arguments:
#   interface: Network interface name
# Outputs:
#   RDMA device name (e.g., mlx5_0) to stdout
# Returns:
#   0 if found, 1 otherwise
#######################################
get_rdma_device() {
    local iface="$1"
    local pci_addr rdma_dev

    pci_addr=$(get_pci_address "$iface") || return 1

    for rdma_dev in /sys/class/infiniband/*; do
        [[ -d "$rdma_dev" ]] || continue
        if readlink -f "$rdma_dev/device" | grep -q "$pci_addr"; then
            basename "$rdma_dev"
            return 0
        fi
    done
    return 1
}

#######################################
# Check if interface is up
# Arguments:
#   interface: Network interface name
# Returns:
#   0 if up, 1 otherwise
#######################################
is_interface_up() {
    local iface="$1"
    local state

    state=$(cat "/sys/class/net/$iface/operstate" 2>/dev/null) || return 1
    [[ "$state" == "up" ]]
}

#######################################
# Get current MTU for interface
# Arguments:
#   interface: Network interface name
# Outputs:
#   MTU value to stdout
# Returns:
#   0 if found, 1 otherwise
#######################################
get_interface_mtu() {
    local iface="$1"
    cat "/sys/class/net/$iface/mtu" 2>/dev/null
}

#######################################
# List all physical network interfaces
# Outputs:
#   Space-separated list of interface names
#######################################
list_physical_interfaces() {
    local iface name
    local interfaces=()

    for iface in /sys/class/net/*; do
        name=$(basename "$iface")
        [[ "$name" == "lo" ]] && continue

        # Skip virtual interfaces
        case "$name" in
            docker*|veth*|br-*|virbr*|vnet*|tun*|tap*) continue ;;
        esac

        # Check if it has a device link (physical)
        [[ -L "$iface/device" ]] && interfaces+=("$name")
    done

    echo "${interfaces[*]}"
}

#######################################
# Get driver name for interface
# Arguments:
#   interface: Network interface name
# Outputs:
#   Driver name to stdout
# Returns:
#   0 if found, 1 otherwise
#######################################
get_interface_driver() {
    local iface="$1"
    local driver_link="/sys/class/net/$iface/device/driver"

    if [[ -L "$driver_link" ]]; then
        basename "$(readlink -f "$driver_link")"
        return 0
    fi
    return 1
}
