#!/bin/bash
set -e

# Full setup for pulse cluster node
# Usage: ./setup.sh

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

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
        if ! sudo -v >/dev/null 2>&1; then
            fatal "sudo access required"
        fi
    fi
}

setup_vf_network() {
    info "Configuring VF network"
    "$REPO_DIR/scripts/setup-vf-network.sh"
}

setup_ptp() {
    info "Setting up PTP"
    "$REPO_DIR/scripts/setup-ptp.sh"
}

start_services() {
    info "Starting PTP service"
    sudo systemctl start ptp4l
}

verify_ptp() {
    if systemctl is-active --quiet ptp4l; then
        info "PTP service running"
    else
        fatal "PTP service failed to start"
    fi
}

# --- Main ---

do_install() {
    info "=== Pulse Node Setup ==="
    verify_sudo
    setup_vf_network
    setup_ptp
    start_services
    verify_ptp
    info "=== Setup Complete ==="
    info "Verify sync: sudo journalctl -u ptp4l -f"
}

do_install
