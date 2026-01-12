#!/bin/bash
# modules/ptp/install.sh - Install and configure PTP time synchronization
#
# Builds patched linuxptp from source for Symmetricom S300 compatibility
# and creates a systemd service for automatic PTP sync.
#
# Environment:
#   PTP_INTERFACE - Override interface (auto-detected by default)
#   PTP_DOMAIN - PTP domain number (default: 0)
#   LINUXPTP_REPO - Git repository for linuxptp source
#
# Files created:
#   /usr/local/sbin/ptp4l
#   /etc/ptp4l.conf
#   /etc/systemd/system/ptp4l.service

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

readonly MODULE_NAME="ptp"
readonly LINUXPTP_DIR="/tmp/linuxptp"
readonly PTP_CONFIG="/etc/ptp4l.conf"
readonly PTP_SERVICE="/etc/systemd/system/ptp4l.service"

#######################################
# Check if PTP already configured
# Returns:
#   0 if installed and service exists, 1 otherwise
#######################################
is_configured() {
    [[ -x /usr/local/sbin/ptp4l ]] && \
    [[ -f "$PTP_CONFIG" ]] && \
    [[ -f "$PTP_SERVICE" ]]
}

#######################################
# Stop existing PTP service if running
#######################################
stop_existing() {
    if systemctl is-active --quiet ptp4l 2>/dev/null; then
        info "[$MODULE_NAME] Stopping existing ptp4l service"
        run_sudo systemctl stop ptp4l
    fi
}

#######################################
# Install build dependencies
#######################################
install_deps() {
    info "[$MODULE_NAME] Installing build dependencies"
    run_sudo apt-get update -qq
    run_sudo apt-get install -y -qq build-essential nettle-dev libgnutls28-dev ethtool git >/dev/null
}

#######################################
# Clone or update linuxptp source
#######################################
clone_source() {
    info "[$MODULE_NAME] Fetching linuxptp source"
    if [[ -d "$LINUXPTP_DIR" ]]; then
        run git -C "$LINUXPTP_DIR" fetch --quiet
        run git -C "$LINUXPTP_DIR" reset --hard origin/master --quiet
    else
        run git clone --quiet "$LINUXPTP_REPO" "$LINUXPTP_DIR"
    fi
}

#######################################
# Build linuxptp
#######################################
build_source() {
    info "[$MODULE_NAME] Building linuxptp"
    cd "$LINUXPTP_DIR"
    run make clean >/dev/null 2>&1 || true
    run make -j"$(nproc)" >/dev/null
}

#######################################
# Install built binaries
#######################################
install_binaries() {
    info "[$MODULE_NAME] Installing to /usr/local/sbin"
    cd "$LINUXPTP_DIR"
    run_sudo make install >/dev/null
}

#######################################
# Create ptp4l configuration
#######################################
create_config() {
    local iface="$1"

    info "[$MODULE_NAME] Creating $PTP_CONFIG"
    run_sudo tee "$PTP_CONFIG" >/dev/null <<EOF
[global]
clientOnly              1
BMCA                    noop
time_stamping           hardware
domainNumber            ${PTP_DOMAIN}

[$iface]
EOF
}

#######################################
# Create systemd service
#######################################
create_service() {
    info "[$MODULE_NAME] Creating systemd service"
    run_sudo tee "$PTP_SERVICE" >/dev/null <<EOF
[Unit]
Description=PTP Clock Sync (linuxptp)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/ptp4l -f /etc/ptp4l.conf
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    run_sudo systemctl daemon-reload
    run_sudo systemctl enable ptp4l.service >/dev/null
}

#######################################
# Main
#######################################
main() {
    debug "[$MODULE_NAME] Starting"

    require_root

    # Determine PTP interface
    local ptp_iface="${PTP_INTERFACE:-}"
    if [[ -z "$ptp_iface" ]]; then
        ptp_iface=$(find_ptp_capable_interface) || fatal "[$MODULE_NAME] No PTP-capable interface found"
    fi

    # Validate interface
    if ! validate_interface "$ptp_iface"; then
        fatal "[$MODULE_NAME] Interface not found: $ptp_iface"
    fi

    info "[$MODULE_NAME] Using interface: $ptp_iface"

    # Check hardware timestamping
    if ! ethtool -T "$ptp_iface" 2>/dev/null | grep -q "hardware-raw-clock"; then
        warn "[$MODULE_NAME] $ptp_iface may not support hardware timestamping"
    fi

    if is_configured; then
        # Update config if interface changed
        if grep -q "^\[$ptp_iface\]" "$PTP_CONFIG" 2>/dev/null; then
            already_configured "$MODULE_NAME"
        fi
        info "[$MODULE_NAME] Interface changed, updating config"
    fi

    stop_existing
    install_deps
    clone_source
    build_source
    install_binaries
    create_config "$ptp_iface"
    create_service

    info "[$MODULE_NAME] Complete"
    info "[$MODULE_NAME] Start with: sudo systemctl start ptp4l"
    info "[$MODULE_NAME] Monitor with: sudo journalctl -u ptp4l -f"
}

main "$@"
