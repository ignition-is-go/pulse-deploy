#!/bin/bash
# modules/hugepages/install.sh - Configure huge pages for Rivermax DMA buffers
#
# Huge pages are required for RDMA/Rivermax to achieve zero-copy DMA.
# This module installs a sysctl config for persistent allocation.
#
# Environment:
#   HUGEPAGES_COUNT - Number of 2MB pages (default: 512 = 1GB)
#
# Files created:
#   /etc/sysctl.d/99-hugepages.conf

set -euo pipefail

# Determine repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# Load libraries
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/validation.sh"

# Load config
source "$REPO_ROOT/config/defaults.conf"

readonly MODULE_NAME="hugepages"
readonly SYSCTL_FILE="/etc/sysctl.d/99-hugepages.conf"

#######################################
# Check if hugepages already configured correctly
# Returns:
#   0 if configured correctly, 1 otherwise
#######################################
is_configured() {
    if [[ ! -f "$SYSCTL_FILE" ]]; then
        return 1
    fi

    # Check if configured with expected count
    local current
    current=$(grep -oP 'vm\.nr_hugepages=\K\d+' "$SYSCTL_FILE" 2>/dev/null) || return 1

    if [[ "$current" -ge "$HUGEPAGES_COUNT" ]]; then
        # Verify actually allocated
        local actual
        actual=$(awk '/HugePages_Total/ {print $2}' /proc/meminfo)
        if [[ "$actual" -ge "$HUGEPAGES_COUNT" ]]; then
            return 0
        fi
    fi
    return 1
}

#######################################
# Install hugepages sysctl configuration
#######################################
install_hugepages() {
    require_root

    # Validate
    if ! validate_positive_int "$HUGEPAGES_COUNT"; then
        fatal "Invalid HUGEPAGES_COUNT: $HUGEPAGES_COUNT"
    fi

    info "[$MODULE_NAME] Configuring $HUGEPAGES_COUNT huge pages ($(( HUGEPAGES_COUNT * 2 ))MB)"

    # Create sysctl config
    run_sudo tee "$SYSCTL_FILE" >/dev/null <<EOF
# Huge pages for Rivermax/DPDK (EVT cameras)
# $HUGEPAGES_COUNT pages * 2MB = $(( HUGEPAGES_COUNT * 2 ))MB
vm.nr_hugepages=$HUGEPAGES_COUNT
EOF

    # Apply immediately
    run_sudo sysctl -p "$SYSCTL_FILE" >/dev/null

    # Verify allocation
    local actual
    actual=$(awk '/HugePages_Total/ {print $2}' /proc/meminfo)

    if [[ "$actual" -lt "$HUGEPAGES_COUNT" ]]; then
        warn "[$MODULE_NAME] Only $actual of $HUGEPAGES_COUNT pages allocated"
        warn "[$MODULE_NAME] Try freeing memory or rebooting"
    else
        info "[$MODULE_NAME] Allocated $actual huge pages"
    fi
}

#######################################
# Main
#######################################
main() {
    debug "[$MODULE_NAME] Starting"

    if is_configured; then
        already_configured "$MODULE_NAME"
    fi

    install_hugepages

    info "[$MODULE_NAME] Complete"
}

main "$@"
