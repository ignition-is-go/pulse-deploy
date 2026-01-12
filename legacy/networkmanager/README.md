# EVT Camera Network Configuration (PF Passthrough)

This configures the Mellanox CX6 interface for EVT camera traffic on a dedicated subnet,
isolated from general VM traffic.

## Network Layout

```
                    ┌─────────────────────────────────────┐
                    │           Mellanox Switch           │
                    └─────────┬───────────────┬───────────┘
                              │               │
                         VLAN/Port        VLAN/Port
                         (EVT cams)       (general)
                              │               │
    ┌─────────────────────────┼───────────────┼─────────────────────────┐
    │ Proxmox Host            │               │                         │
    │                    ┌────┴────┐     ┌────┴────┐                    │
    │                    │ CX6 PF  │     │ Other   │                    │
    │                    │ (VFIO)  │     │ NIC     │                    │
    │                    └────┬────┘     └────┬────┘                    │
    └─────────────────────────┼───────────────┼─────────────────────────┘
                              │               │
                         PCI Passthrough  virtio bridge
                              │               │
    ┌─────────────────────────┼───────────────┼─────────────────────────┐
    │ VM                      │               │                         │
    │                    ┌────┴────┐     ┌────┴────┐                    │
    │                    │enp2s0f0 │     │enp6s18  │                    │
    │                    │10.0.0.1 │     │DHCP     │                    │
    │                    │/24      │     │192.168.x│                    │
    │                    │MTU 9000 │     │         │                    │
    │                    └─────────┘     └─────────┘                    │
    │                         │               │                         │
    │                    EVT/Rivermax    General traffic                │
    │                    raw sockets     (SSH, web, etc)                │
    └─────────────────────────────────────────────────────────────────────┘
```

## Installation

```bash
# Copy connection file (requires root)
sudo cp evt-camera-network.nmconnection /etc/NetworkManager/system-connections/
sudo chmod 600 /etc/NetworkManager/system-connections/evt-camera-network.nmconnection
sudo chown root:root /etc/NetworkManager/system-connections/evt-camera-network.nmconnection

# Remove old connection and reload
sudo nmcli connection delete mellanox 2>/dev/null || true
sudo nmcli connection reload
sudo nmcli connection up evt-cameras
```

## EVT Camera Configuration

After applying this config, reconfigure EVT cameras to the 10.0.0.0/24 subnet:

| Device | IP Address | Notes |
|--------|------------|-------|
| VM (CX6) | 10.0.0.1 | Gateway for cameras (not really used) |
| EVT Camera 1 | 10.0.0.10 | |
| EVT Camera 2 | 10.0.0.11 | |
| ... | 10.0.0.x | |

Configure camera IPs via eCapture or optik (EVT SDK).

## Verification

```bash
# Check interface config
ip addr show enp2s0f0np0

# Should show:
#   inet 10.0.0.1/24 ...
#   mtu 9000

# Test camera connectivity (after camera IP change)
ping 10.0.0.10

# Verify Rivermax can bind
# (requires running the app with proper permissions)
```

## Why Dedicated Subnet?

1. **Routing clarity**: No ambiguity about which interface handles EVT traffic
2. **Isolation**: EVT raw socket traffic doesn't interfere with general networking
3. **Security**: Camera network is air-gapped from internet-routable traffic
4. **Simplicity**: No need for policy routing or static host routes
