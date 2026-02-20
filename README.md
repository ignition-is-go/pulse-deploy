# pulse-deploy

Deployment automation for [Pulse](https://github.com/ignition-is-go) - a platform for production systems including control, video, AI/ML inference, lighting, and more.

## Overview

Pulse runs on heterogeneous hardware configurations with different node types serving different roles:

- **Optik nodes** - Video/camera processing with EVT cameras, GPU-direct, PTP boundary clock
- **Unreal nodes** - Real-time graphics rendering
- **Arnold nodes** - Offline rendering (Arnold/Fusion)
- **rship nodes** - Real-time communication infrastructure
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
├── ansible.cfg               # Ansible configuration (default inventory: hrlv)
├── inventories/              # Deployment environments
│   ├── hrlv/                 # HRLV production environment
│   │   ├── hosts.yml
│   │   └── group_vars/
│   └── example/              # Template for new environments
├── playbooks/                # Ansible playbooks
│   ├── site.yml              # Full convergence
│   ├── deploy.yml            # Day-to-day Plastic sync + worker
│   ├── build.yml             # UE build pipeline
│   └── status.yml            # Fleet status checks
├── roles/                    # Composable Ansible roles
├── collections/              # Ansible Galaxy requirements
├── infra/                    # Terraform (Proxmox provisioning)
├── scripts/                  # Bootstrap scripts
│   └── bootstrap-ansible.ps1     # One-time Windows VM bootstrap
├── setup.sh                  # Shell orchestrator (Optik VM-level config)
├── config/
│   └── defaults.conf         # Default configuration values
├── lib/                      # Shared shell libraries
│   ├── common.sh             # Logging, utilities
│   ├── detect.sh             # Hardware detection
│   └── validation.sh         # Input validation
├── modules/                  # Shell deployment modules
│   ├── hugepages/            # RDMA/Rivermax memory
│   ├── network/              # EVT camera network
│   ├── ptp/                  # PTP time sync
│   └── evt/                  # EVT camera routes
├── tests/                    # Validation scripts
└── docs/                     # Documentation
```

## Ansible Fleet Management

Manages the full render farm fleet via composable role layers:

```
Layer 0: OS base       → win_base, linux_base, lxc_base
Layer 1: Drivers       → nvidia_gpu_win, nvidia_gpu_linux, rivermax
Layer 2: Shared infra  → smb_share, linux_storage, plastic_scm
Layer 3: Applications  → unreal_engine, render_worker, arnold, optik, rship
```

```bash
# Full convergence (uses default inventory from ansible.cfg)
ansible-playbook playbooks/site.yml

# Day-to-day deploy (Plastic sync + worker update)
ansible-playbook playbooks/deploy.yml

# Target specific nodes
ansible-playbook playbooks/site.yml --limit ue

# Use a different environment
ansible-playbook playbooks/site.yml -i inventories/staging/hosts.yml

# Status checks
ansible-playbook playbooks/status.yml
```

### New Environment

```bash
cp -r inventories/example inventories/mysite
# Edit inventories/mysite/hosts.yml
# Encrypt vault: ansible-vault encrypt inventories/mysite/group_vars/all/vault.yml
ansible-playbook playbooks/site.yml -i inventories/mysite/hosts.yml
```

See [`CLAUDE.md`](CLAUDE.md) for full Ansible architecture reference.

## Shell Modules (Optik VM Config)

```bash
# Preview changes (safe, no modifications)
DRY_RUN=1 ./setup.sh

# Deploy all modules
sudo ./setup.sh

# Single module
sudo ./setup.sh --module ptp

# List modules
./setup.sh --list

# Validate
./tests/validate-all.sh
```

### Configuration

Edit `config/defaults.conf` or override via environment:

| Variable | Default | Description |
|----------|---------|-------------|
| `HUGEPAGES_COUNT` | 512 | 2MB huge pages (512 = 1GB) |
| `EVT_CAMERA_SUBNET` | 10.0.0.0/24 | EVT camera network |
| `EVT_HOST_IP` | 10.0.0.1 | Host IP on EVT network |
| `CX6_MTU` | 9000 | ConnectX MTU |
| `PTP_DOMAIN` | 0 | PTP domain number |

## Documentation

- [Deployment Repository Guide](docs/DEPLOYMENT_REPO_GUIDE.md) - Structure, conventions, and patterns
- [OpenShift Migration](docs/OPENSHIFT_MIGRATION.md) - Future migration path
- [Proxmox Guides](docs/proxmox/README.md) - Host-level configuration (GPU passthrough, SR-IOV, etc.)
- [ConnectX-6 SR-IOV](docs/connectx6-sriov.md) - Mellanox NIC configuration

## Post-Deployment

```bash
# Start PTP
sudo systemctl start ptp4l
sudo journalctl -u ptp4l -f

# Configure EVT cameras to 10.0.0.x via eCapture or optik
```
