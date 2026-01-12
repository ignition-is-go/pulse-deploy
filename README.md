# pulse-deploy

Deployment automation for [Pulse](https://github.com/ignition-is-go) - a platform for production systems including control, video, AI/ML inference, lighting, and more.

## Overview

Pulse runs on heterogeneous hardware configurations with different node types serving different roles:

- **Optik nodes** - Video/camera processing with EVT cameras, GPU-direct, PTP boundary clock
- **Unreal nodes** - Real-time graphics rendering
- **Inference nodes** - AI/ML workloads
- **Control nodes** - System orchestration

This repository automates deployment across these configurations, abstracting platform differences (Proxmox VMs today, RHEL bare-metal in future).

## Target Hardware

Primary production hardware: [Gigabyte R113-C10](https://www.newegg.com/gigabyte-r113-c10-aa01-l1-amd-epyc-4004-series/p/16-202-308)
- AMD EPYC 4004 series
- 8x NVIDIA RTX 6000 Ada GPUs
- 2x Mellanox ConnectX-6 NICs

Current virtualization: **Proxmox** with GPU/NIC passthrough to VMs
Future target: **Red Hat OpenShift Virtualization** (KubeVirt-based)

## Repository Structure

```
pulse-deploy/
├── setup.sh              # Main orchestrator
├── config/
│   └── defaults.conf     # Default configuration values
├── lib/                  # Shared shell libraries
│   ├── common.sh         # Logging, utilities
│   ├── detect.sh         # Hardware detection
│   └── validation.sh     # Input validation
├── modules/              # Deployment modules
│   ├── hugepages/        # RDMA/Rivermax memory
│   ├── network/          # EVT camera network
│   ├── ptp/              # PTP time sync
│   └── evt/              # EVT camera routes
├── tests/                # Validation scripts
└── docs/                 # Documentation
```

## Quick Start

```bash
git clone https://github.com/ignition-is-go/pulse-deploy.git
cd pulse-deploy

# Preview changes (safe, no modifications)
DRY_RUN=1 ./setup.sh

# Deploy
sudo ./setup.sh

# Validate
./tests/validate-all.sh
```

## Usage

```bash
# Full deployment
sudo ./setup.sh

# Single module
sudo ./setup.sh --module ptp

# List modules
./setup.sh --list

# Debug output
DEPLOY_DEBUG=1 sudo ./setup.sh
```

## Configuration

Edit `config/defaults.conf` or override via environment:

| Variable | Default | Description |
|----------|---------|-------------|
| `HUGEPAGES_COUNT` | 512 | 2MB huge pages (512 = 1GB) |
| `EVT_CAMERA_SUBNET` | 10.0.0.0/24 | EVT camera network |
| `EVT_HOST_IP` | 10.0.0.1 | Host IP on EVT network |
| `CX6_MTU` | 9000 | ConnectX MTU |
| `PTP_DOMAIN` | 0 | PTP domain number |

## Current Scope

This repo currently handles **VM-level configuration** for Optik nodes:
- Huge pages for Rivermax DMA
- ConnectX-6 network configuration
- PTP boundary clock (patched linuxptp for Symmetricom S300)
- EVT camera routing

## Future Work

- [ ] Node role profiles (optik, unreal, inference, control)
- [ ] Platform abstraction (Proxmox vs OpenShift Virtualization)
- [ ] Host-level configuration (BIOS, hypervisor, GPU/NIC passthrough)
- [ ] NVIDIA driver/CUDA module (GPU Operator on OpenShift)
- [ ] OpenShift tooling (Operators, GitOps/ArgoCD, ACM)
- [ ] Mixed VM + container workloads

## Documentation

- [Deployment Repository Guide](docs/DEPLOYMENT_REPO_GUIDE.md) - Structure, conventions, and patterns
- Host configuration notes (BIOS, Proxmox) - TODO

## Post-Deployment

```bash
# Start PTP
sudo systemctl start ptp4l
sudo journalctl -u ptp4l -f

# Configure EVT cameras to 10.0.0.x via eCapture or optik
```
