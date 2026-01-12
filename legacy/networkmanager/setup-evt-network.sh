#!/bin/bash
# Setup EVT camera network on CX6 interface
# Detects Mellanox CX6 by vendor ID and creates NetworkManager connection

set -e

SUBNET="10.0.0.1/24"
MTU=9000
CONN_NAME="evt-cameras"

# Find Mellanox CX6 interface by vendor (15b3 = Mellanox)
CX6_IFACE=""
CX6_MAC=""

for iface in /sys/class/net/*; do
    name=$(basename "$iface")
    [[ "$name" == "lo" ]] && continue

    vendor_file="$iface/device/vendor"
    [[ -f "$vendor_file" ]] || continue

    vendor=$(cat "$vendor_file" 2>/dev/null)
    if [[ "$vendor" == "0x15b3" ]]; then
        # First Mellanox interface found (port 0)
        CX6_IFACE="$name"
        CX6_MAC=$(cat "$iface/address")
        break
    fi
done

if [[ -z "$CX6_IFACE" ]]; then
    echo "ERROR: No Mellanox CX6 interface found"
    exit 1
fi

echo "Found CX6: $CX6_IFACE (MAC: $CX6_MAC)"

# Generate nmconnection file
CONN_FILE="/etc/NetworkManager/system-connections/${CONN_NAME}.nmconnection"

cat > /tmp/evt-cameras.nmconnection << EOF
[connection]
id=${CONN_NAME}
uuid=$(uuidgen)
type=ethernet
autoconnect=true
autoconnect-priority=100

[ethernet]
mac-address=${CX6_MAC^^}
mtu=${MTU}

[ipv4]
method=manual
addresses=${SUBNET}
never-default=true
may-fail=false

[ipv6]
method=disabled
EOF

# Install the connection
echo "Installing NetworkManager connection..."
sudo cp /tmp/evt-cameras.nmconnection "$CONN_FILE"
sudo chmod 600 "$CONN_FILE"
sudo chown root:root "$CONN_FILE"
rm /tmp/evt-cameras.nmconnection

# Remove any existing connection on this interface
existing=$(nmcli -t -f NAME,DEVICE connection show | grep ":${CX6_IFACE}$" | cut -d: -f1)
if [[ -n "$existing" && "$existing" != "$CONN_NAME" ]]; then
    echo "Removing existing connection: $existing"
    sudo nmcli connection delete "$existing" 2>/dev/null || true
fi

# Reload and activate
sudo nmcli connection reload
sudo nmcli connection up "$CONN_NAME"

echo ""
echo "EVT camera network configured:"
echo "  Interface: $CX6_IFACE"
echo "  MAC: $CX6_MAC"
echo "  IP: $SUBNET"
echo "  MTU: $MTU"
echo ""
echo "Configure EVT cameras to 10.0.0.x subnet via eCapture or optik."
