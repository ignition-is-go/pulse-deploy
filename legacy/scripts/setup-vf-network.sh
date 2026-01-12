#!/bin/bash
set -e

# Configure DHCP for ConnectX VF interface
# Usage: ./setup-vf-network.sh
#        VF_INTERFACE=enp2s0 ./setup-vf-network.sh

NETPLAN_FILE="/etc/netplan/vf.yaml"

# --- Logging ---

info() {
    echo "[INFO] $*"
}

warn() {
    echo "[WARN] $*" >&2
}

fatal() {
    echo "[ERROR] $*" >&2
    exit 1
}

# --- Functions ---

verify_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        if ! command -v sudo >/dev/null 2>&1; then
            fatal "This script requires root privileges"
        fi
        if ! sudo -v >/dev/null 2>&1; then
            fatal "sudo access required"
        fi
        SUDO="sudo"
    else
        SUDO=""
    fi
}

detect_interface() {
    for path in /sys/class/net/*; do
        iface=$(basename "$path")
        [ "$iface" = "lo" ] && continue
        case "$iface" in docker*|veth*|br-*) continue ;; esac
        if ethtool -T "$iface" 2>/dev/null | grep -q "PTP Hardware Clock: [0-9]"; then
            echo "$iface"
            return 0
        fi
    done
    return 1
}

verify_interface() {
    if [ -z "$VF_INTERFACE" ]; then
        VF_INTERFACE=$(detect_interface) || fatal "No VF interface found. Set VF_INTERFACE env var."
    fi
    [ -d "/sys/class/net/$VF_INTERFACE" ] || fatal "Interface $VF_INTERFACE not found"
    info "Using interface: $VF_INTERFACE"
}

check_existing() {
    if ip addr show "$VF_INTERFACE" 2>/dev/null | grep -q "inet "; then
        addr=$(ip -4 addr show "$VF_INTERFACE" | grep -oP 'inet \K[\d.]+' || true)
        info "Already configured: $VF_INTERFACE ($addr)"
        exit 0
    fi
}

create_netplan() {
    info "Creating $NETPLAN_FILE"
    $SUDO tee "$NETPLAN_FILE" >/dev/null <<EOF
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    $VF_INTERFACE:
      dhcp4: true
EOF
    $SUDO chmod 600 "$NETPLAN_FILE"
}

apply_netplan() {
    info "Applying netplan"
    $SUDO netplan apply
}

wait_for_dhcp() {
    info "Waiting for DHCP lease"
    for i in $(seq 1 15); do
        if ip addr show "$VF_INTERFACE" 2>/dev/null | grep -q "inet "; then
            return 0
        fi
        sleep 1
    done
    return 1
}

verify_network() {
    if ip addr show "$VF_INTERFACE" | grep -q "inet "; then
        addr=$(ip -4 addr show "$VF_INTERFACE" | grep -oP 'inet \K[\d./]+' || true)
        info "Success: $VF_INTERFACE ($addr)"
    else
        fatal "DHCP lease failed"
    fi
}

# --- Main ---

do_install() {
    verify_sudo
    verify_interface
    check_existing
    create_netplan
    apply_netplan
    wait_for_dhcp
    verify_network
}

do_install
