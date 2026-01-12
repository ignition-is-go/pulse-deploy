#!/bin/bash
# modules/evt/install.sh - Configure routes for EVT cameras
#
# Adds network routes through the Mellanox NIC for EVT camera traffic.
# Can auto-discover cameras using the EVT SDK or route entire subnets.
#
# Environment:
#   EVT_CAMERA_SUBNET - Subnet to route (if set, skips discovery)
#   EVT_CONNECTION_NAME - NetworkManager connection name
#
# Usage:
#   ./install.sh                     # Auto-discover cameras
#   ./install.sh 192.168.1.0/24      # Route specific subnet
#   ./install.sh 192.168.1.10        # Route single IP

set -euo pipefail

# Determine repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# Load libraries
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/validation.sh"

# Load config
source "$REPO_ROOT/config/defaults.conf"

readonly MODULE_NAME="evt"
readonly EVT_SDK_DISCOVER="/opt/EVT/eSDK/samples/ListDevices/ListDevices"

#######################################
# Add a route through the EVT network connection
# Arguments:
#   target: IP or CIDR to route
#######################################
add_route() {
    local target="$1"

    # Ensure CIDR notation
    if [[ "$target" != */* ]]; then
        target="${target}/32"
    fi

    # Validate
    if ! validate_cidr "$target"; then
        err "[$MODULE_NAME] Invalid route target: $target"
        return 1
    fi

    # Check connection exists
    if ! nmcli connection show "$EVT_CONNECTION_NAME" &>/dev/null; then
        fatal "[$MODULE_NAME] Connection not found: $EVT_CONNECTION_NAME"
    fi

    # Check if route already exists
    if nmcli connection show "$EVT_CONNECTION_NAME" 2>/dev/null | grep -q "${target%/*}"; then
        info "[$MODULE_NAME] Route already configured: $target"
        return 0
    fi

    info "[$MODULE_NAME] Adding route: $target via $EVT_CONNECTION_NAME"
    run_sudo nmcli connection modify "$EVT_CONNECTION_NAME" +ipv4.routes "$target"
}

#######################################
# Discover EVT cameras and add routes
#######################################
discover_cameras() {
    if [[ ! -x "$EVT_SDK_DISCOVER" ]]; then
        warn "[$MODULE_NAME] EVT SDK discovery tool not found: $EVT_SDK_DISCOVER"
        warn "[$MODULE_NAME] Specify camera IPs manually: $0 <ip>"
        return 1
    fi

    info "[$MODULE_NAME] Discovering EVT cameras..."

    local ips
    ips=$("$EVT_SDK_DISCOVER" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u) || true

    if [[ -z "$ips" ]]; then
        warn "[$MODULE_NAME] No cameras discovered"
        return 0
    fi

    local ip
    for ip in $ips; do
        add_route "$ip"
    done
}

#######################################
# Main
#######################################
main() {
    debug "[$MODULE_NAME] Starting"

    require_root

    # Verify connection exists
    if ! nmcli connection show "$EVT_CONNECTION_NAME" &>/dev/null; then
        fatal "[$MODULE_NAME] EVT network not configured. Run network module first."
    fi

    if [[ $# -gt 0 ]]; then
        # Manual IPs/subnets specified
        for target in "$@"; do
            add_route "$target"
        done
    elif [[ -n "${EVT_CAMERA_SUBNET:-}" ]]; then
        # Subnet pre-configured - just verify routes
        info "[$MODULE_NAME] EVT camera subnet: $EVT_CAMERA_SUBNET"
        # Routes through the EVT interface are implicit from the address config
    else
        # Auto-discover
        discover_cameras
    fi

    # Bring connection up to apply changes
    run_sudo nmcli connection up "$EVT_CONNECTION_NAME" >/dev/null 2>&1 || true

    info "[$MODULE_NAME] Complete"
    info "[$MODULE_NAME] Configure cameras to ${EVT_CAMERA_SUBNET} via eCapture or optik"
}

main "$@"
