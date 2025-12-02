# pulse-deploy

Deployment scripts for pulse cluster nodes.

## Quick Start

```bash
git clone https://github.com/ignition-is-go/pulse-deploy.git
cd pulse-deploy
./setup.sh
```

## What it does

1. Configures DHCP for ConnectX VF interface
2. Builds and installs patched [linuxptp](https://github.com/ignition-is-go/linuxptp)
3. Creates systemd service for PTP sync

## Requirements

- Ubuntu 24.04
- ConnectX-6 VF passed through to VM
- Network with DHCP and PTP grandmaster

## Verify

```bash
sudo journalctl -u ptp4l -f
```
