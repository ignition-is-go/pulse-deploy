#!/bin/bash
#
# Setup script for EVT camera support on Pulse cluster nodes.
#
# Configures:
#   - Huge pages for Rivermax DMA buffers
#   - Network routes for EVT camera traffic through Mellanox NIC
#
# Usage:
#   setup-evt.sh                    # Auto-discover cameras and add routes
#   setup-evt.sh 192.168.1.0/24     # Route entire subnet
#   setup-evt.sh 192.168.1.69       # Route single camera IP

set -o errexit
set -o nounset
set -o pipefail

#######################################
# Constants
#######################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly REPO_DIR
readonly CONFIG_FILE="/etc/pulse/evt.conf"
readonly SYSCTL_SOURCE="${REPO_DIR}/sysctl.d/99-hugepages.conf"
readonly EVT_SDK_DISCOVER="/opt/EVT/eSDK/samples/ListDevices/ListDevices"

# Load site config if present
# shellcheck source=/dev/null
[[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}"

# Configurable via environment or config file
readonly MELLANOX_CONNECTION="${MELLANOX_CONNECTION:-mellanox}"
readonly EVT_CAMERA_SUBNET="${EVT_CAMERA_SUBNET:-}"

#######################################
# Logging functions
#######################################

info() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*" >&2
}

err() {
  echo "[ERROR] $*" >&2
}

#######################################
# Install huge pages sysctl configuration.
# Globals:
#   SYSCTL_SOURCE
# Outputs:
#   Writes to stdout
#######################################
setup_hugepages() {
  info "Installing huge pages config"

  if [[ ! -f "${SYSCTL_SOURCE}" ]]; then
    err "Sysctl config not found: ${SYSCTL_SOURCE}"
    return 1
  fi

  sudo mkdir -p /etc/sysctl.d
  sudo cp "${SYSCTL_SOURCE}" /etc/sysctl.d/
  sudo sysctl -p /etc/sysctl.d/99-hugepages.conf >/dev/null

  local pages
  pages="$(awk '/HugePages_Total/ {print $2}' /proc/meminfo)"
  info "Huge pages allocated: ${pages}"
}

#######################################
# Add a network route through the Mellanox NIC.
# Globals:
#   MELLANOX_CONNECTION
#   CONFIG_FILE
# Arguments:
#   target: IP address or CIDR subnet (e.g., 192.168.1.69 or 192.168.1.0/24)
# Returns:
#   0 on success, 1 on failure
#######################################
add_route() {
  local target="$1"

  # Ensure CIDR notation
  if [[ "${target}" != */* ]]; then
    target="${target}/32"
  fi

  # Verify connection exists
  if ! nmcli connection show "${MELLANOX_CONNECTION}" &>/dev/null; then
    err "NetworkManager connection '${MELLANOX_CONNECTION}' not found"
    err "Set MELLANOX_CONNECTION in ${CONFIG_FILE}"
    return 1
  fi

  # Check if route already configured
  if nmcli connection show "${MELLANOX_CONNECTION}" | grep -q "${target%/*}"; then
    info "Route for ${target} already configured"
    return 0
  fi

  info "Adding route for ${target} via ${MELLANOX_CONNECTION}"
  sudo nmcli connection modify "${MELLANOX_CONNECTION}" +ipv4.routes "${target}"
  sudo nmcli connection up "${MELLANOX_CONNECTION}" >/dev/null
}

#######################################
# Discover EVT cameras and add routes for each.
# Globals:
#   EVT_SDK_DISCOVER
# Outputs:
#   Writes discovered camera IPs to stdout
# Returns:
#   0 on success, 1 if no discovery tool available
#######################################
discover_and_route() {
  if [[ ! -x "${EVT_SDK_DISCOVER}" ]]; then
    warn "EVT SDK discovery tool not found: ${EVT_SDK_DISCOVER}"
    warn "Specify camera IPs manually: $0 <ip>"
    return 1
  fi

  info "Discovering EVT cameras..."

  local ips
  ips="$("${EVT_SDK_DISCOVER}" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u)" || true

  if [[ -z "${ips}" ]]; then
    warn "No EVT cameras discovered"
    return 0
  fi

  local ip
  for ip in ${ips}; do
    add_route "${ip}"
  done
}

#######################################
# Main entry point.
# Arguments:
#   Optional: IP addresses or subnets to route
#######################################
main() {
  info "=== EVT Camera Setup ==="

  setup_hugepages

  if [[ $# -gt 0 ]]; then
    # Manual IPs/subnets specified
    local target
    for target in "$@"; do
      add_route "${target}"
    done
  elif [[ -n "${EVT_CAMERA_SUBNET}" ]]; then
    # Subnet configured via environment
    add_route "${EVT_CAMERA_SUBNET}"
  else
    # Auto-discover
    discover_and_route
  fi

  info "=== EVT Setup Complete ==="
}

main "$@"
