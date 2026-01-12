#!/bin/bash
set -e

# Install patched linuxptp with Symmetricom S300 compatibility
# Usage: ./setup-ptp.sh
#        PTP_INTERFACE=enp2s0 ./setup-ptp.sh

LINUXPTP_REPO="https://github.com/ignition-is-go/linuxptp.git"
LINUXPTP_DIR="/tmp/linuxptp"
PTP_CONFIG="/etc/ptp4l.conf"

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
    if [ -z "$PTP_INTERFACE" ]; then
        PTP_INTERFACE=$(detect_interface) || fatal "No PTP-capable interface found. Set PTP_INTERFACE env var."
    fi
    [ -d "/sys/class/net/$PTP_INTERFACE" ] || fatal "Interface $PTP_INTERFACE not found"
    info "Using interface: $PTP_INTERFACE"

    if ! ethtool -T "$PTP_INTERFACE" 2>/dev/null | grep -q "hardware-raw-clock"; then
        warn "$PTP_INTERFACE may not support hardware timestamping"
    fi
}

stop_existing() {
    if systemctl is-active --quiet ptp4l 2>/dev/null; then
        info "Stopping existing ptp4l service"
        $SUDO systemctl stop ptp4l
    fi
}

install_dependencies() {
    info "Installing build dependencies"
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq build-essential nettle-dev libgnutls28-dev ethtool >/dev/null
}

clone_linuxptp() {
    info "Fetching linuxptp"
    if [ -d "$LINUXPTP_DIR" ]; then
        git -C "$LINUXPTP_DIR" pull --quiet
    else
        git clone --quiet "$LINUXPTP_REPO" "$LINUXPTP_DIR"
    fi
}

build_linuxptp() {
    info "Building linuxptp"
    cd "$LINUXPTP_DIR"
    make clean >/dev/null 2>&1 || true
    make -j"$(nproc)" >/dev/null
}

install_linuxptp() {
    info "Installing to /usr/local/sbin"
    cd "$LINUXPTP_DIR"
    $SUDO make install >/dev/null
}

create_config() {
    info "Creating $PTP_CONFIG"
    $SUDO tee "$PTP_CONFIG" >/dev/null <<EOF
[global]
time_stamping           hardware
domainNumber            0

[$PTP_INTERFACE]
EOF
}

create_service() {
    info "Creating systemd service"
    $SUDO tee /etc/systemd/system/ptp4l.service >/dev/null <<EOF
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
    $SUDO systemctl daemon-reload
    $SUDO systemctl enable ptp4l.service >/dev/null
}

# --- Main ---

do_install() {
    verify_sudo
    verify_interface
    stop_existing
    install_dependencies
    clone_linuxptp
    build_linuxptp
    install_linuxptp
    create_config
    create_service
    info "Setup complete"
}

do_install
