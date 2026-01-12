#!/bin/bash
# tests/validate-all.sh - Post-deployment validation
#
# Verifies that all components are properly configured after deployment.
# Run this after setup.sh completes.
#
# Exit codes:
#   0 - All validations passed
#   1 - One or more validations failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/detect.sh"
source "$REPO_ROOT/config/defaults.conf"

FAILED=0

#######################################
# Run a validation check
# Arguments:
#   name: Name of the check
#   command: Command to run
#######################################
check() {
    local name="$1"
    shift

    if "$@" &>/dev/null; then
        echo "[PASS] $name"
    else
        echo "[FAIL] $name"
        ((FAILED++))
    fi
}

#######################################
# Main
#######################################
main() {
    info "=== Post-Deployment Validation ==="
    echo ""

    # Hugepages
    info "Checking hugepages..."
    check "Sysctl config exists" test -f /etc/sysctl.d/99-hugepages.conf
    check "Hugepages allocated" test "$(awk '/HugePages_Total/ {print $2}' /proc/meminfo)" -ge "$HUGEPAGES_COUNT"
    echo ""

    # Network
    info "Checking network..."
    check "NetworkManager running" systemctl is-active NetworkManager
    check "EVT connection exists" nmcli connection show "$EVT_CONNECTION_NAME"

    local cx6_iface
    cx6_iface=$(find_mellanox_interface 2>/dev/null) || cx6_iface=""
    if [[ -n "$cx6_iface" ]]; then
        check "Mellanox interface found ($cx6_iface)" test -d "/sys/class/net/$cx6_iface"
        check "Interface MTU is $CX6_MTU" test "$(cat /sys/class/net/$cx6_iface/mtu 2>/dev/null)" -eq "$CX6_MTU"
    else
        echo "[SKIP] Mellanox interface not found"
    fi
    echo ""

    # PTP
    info "Checking PTP..."
    check "ptp4l binary installed" test -x /usr/local/sbin/ptp4l
    check "ptp4l config exists" test -f /etc/ptp4l.conf
    check "ptp4l service exists" test -f /etc/systemd/system/ptp4l.service
    check "ptp4l service enabled" systemctl is-enabled ptp4l

    if systemctl is-active ptp4l &>/dev/null; then
        echo "[PASS] ptp4l service running"
    else
        echo "[INFO] ptp4l service not running (start with: sudo systemctl start ptp4l)"
    fi
    echo ""

    # Summary
    info "=== Validation Summary ==="
    if [[ $FAILED -eq 0 ]]; then
        info "All checks passed!"
        exit 0
    else
        err "$FAILED check(s) failed"
        exit 1
    fi
}

main "$@"
