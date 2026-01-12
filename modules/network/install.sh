#!/bin/bash
# modules/network/install.sh - Configure network for EVT cameras
#
# Detects Mellanox ConnectX interface and creates a NetworkManager connection
# for the EVT camera subnet with appropriate MTU and static IP.
#
# Environment:
#   EVT_CAMERA_SUBNET - CIDR subnet (default: 10.0.0.0/24)
#   EVT_HOST_IP - Host IP on EVT network (default: 10.0.0.1)
#   EVT_CONNECTION_NAME - NM connection name (default: evt-cameras)
#   CX6_MTU - MTU size (default: 9000)
#
# Files created:
#   /etc/NetworkManager/system-connections/evt-cameras.nmconnection

set -euo pipefail

# Determine repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# Load libraries
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/detect.sh"
source "$REPO_ROOT/lib/validation.sh"

# Load config
source "$REPO_ROOT/config/defaults.conf"

readonly MODULE_NAME="network"

#######################################
# Check if EVT network already configured
# Returns:
#   0 if configured, 1 otherwise
#######################################
is_configured() {
    # Check if connection exists and is active
    if nmcli connection show "$EVT_CONNECTION_NAME" &>/dev/null; then
        if nmcli connection show --active | grep -q "$EVT_CONNECTION_NAME"; then
            return 0
        fi
    fi
    return 1
}

#######################################
# Configure EVT camera network
#######################################
install_network() {
    require_root

    # Find Mellanox interface
    local cx6_iface cx6_mac
    cx6_iface=$(find_mellanox_interface) || fatal "[$MODULE_NAME] No Mellanox interface found"
    cx6_mac=$(get_mac_address "$cx6_iface") || fatal "[$MODULE_NAME] Cannot get MAC for $cx6_iface"

    info "[$MODULE_NAME] Found ConnectX: $cx6_iface (MAC: $cx6_mac)"

    # Extract prefix from subnet CIDR
    local prefix="${EVT_CAMERA_SUBNET#*/}"
    local host_cidr="${EVT_HOST_IP}/${prefix}"

    # Validate
    if ! validate_cidr "$host_cidr"; then
        fatal "[$MODULE_NAME] Invalid host IP/prefix: $host_cidr"
    fi

    if ! validate_positive_int "$CX6_MTU"; then
        fatal "[$MODULE_NAME] Invalid MTU: $CX6_MTU"
    fi

    # Generate connection file
    local conn_file="/etc/NetworkManager/system-connections/${EVT_CONNECTION_NAME}.nmconnection"
    local uuid
    uuid=$(uuidgen)

    info "[$MODULE_NAME] Creating NetworkManager connection: $EVT_CONNECTION_NAME"

    run_sudo tee "$conn_file" >/dev/null <<EOF
[connection]
id=${EVT_CONNECTION_NAME}
uuid=${uuid}
type=ethernet
autoconnect=true
autoconnect-priority=100

[ethernet]
mac-address=${cx6_mac}
mtu=${CX6_MTU}

[ipv4]
method=manual
addresses=${host_cidr}
never-default=true
may-fail=false

[ipv6]
method=disabled
EOF

    # Secure the file
    run_sudo chmod 600 "$conn_file"
    run_sudo chown root:root "$conn_file"

    # Remove any existing connection on this interface
    local existing
    existing=$(nmcli -t -f NAME,DEVICE connection show 2>/dev/null | grep ":${cx6_iface}$" | cut -d: -f1) || true
    if [[ -n "$existing" && "$existing" != "$EVT_CONNECTION_NAME" ]]; then
        info "[$MODULE_NAME] Removing existing connection: $existing"
        run_sudo nmcli connection delete "$existing" 2>/dev/null || true
    fi

    # Reload and activate
    run_sudo nmcli connection reload
    run_sudo nmcli connection up "$EVT_CONNECTION_NAME"

    info "[$MODULE_NAME] Configured $cx6_iface with $host_cidr (MTU: $CX6_MTU)"
}

#######################################
# Main
#######################################
main() {
    debug "[$MODULE_NAME] Starting"

    # Check for NetworkManager
    assert_command nmcli "apt install network-manager"

    if is_configured; then
        already_configured "$MODULE_NAME"
    fi

    install_network

    info "[$MODULE_NAME] Complete"
}

main "$@"
