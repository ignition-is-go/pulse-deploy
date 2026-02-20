# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Ansible configuration for managing a multi-OS render farm infrastructure on Proxmox. Manages Windows UE/Arnold render nodes, Linux CV VMs (Optik), Linux LXC containers (rship), and a Linux control plane.

## Architecture

**Design: Layers, Not Types** — Every node is built from composable Ansible roles (layers). A node's identity = which layers are applied.

```
Layer 0: OS base       → win_base, linux_base, lxc_base
Layer 1: Drivers       → nvidia_gpu_win, nvidia_gpu_linux, rivermax
Layer 2: Shared infra  → smb_share, linux_storage, plastic_scm
Layer 3: Applications  → unreal_engine, render_worker, arnold, optik, rship
```

**Fleet:**
- **Windows VMs**: UE render/previs nodes (7), Arnold/Fusion nodes (TBD)
- **Linux VMs**: Optik CV (1), Ansible control plane (1)
- **LXC containers**: rship nodes (3), rship control plane (1)

**Connections:**
- Windows VMs: WinRM (port 5985, NTLM auth)
- Linux VMs/LXC: SSH
- Control node: local connection

## Commands

```bash
# Full convergence — everything
ansible-playbook playbooks/site.yml

# Target by group
ansible-playbook playbooks/site.yml --limit windows
ansible-playbook playbooks/site.yml --limit ue
ansible-playbook playbooks/site.yml --limit lxc

# Target single node
ansible-playbook playbooks/site.yml --limit windows-unreal-03

# Day-to-day deploy (Plastic sync + worker update)
ansible-playbook playbooks/deploy.yml
ansible-playbook playbooks/deploy.yml --limit windows-unreal-03
ansible-playbook playbooks/deploy.yml -e "skip_plastic=true"

# Status checks
ansible-playbook playbooks/status.yml
ansible-playbook playbooks/plastic-status.yml

# Build pipeline
ansible-playbook playbooks/build.yml --limit windows-unreal-dev-01

# Use a different inventory/environment
ansible-playbook playbooks/site.yml -i inventories/hrlv-prod

# Connectivity test
ansible all -m ping

# Vault
ansible-vault encrypt inventories/hrlv-dev/group_vars/all/vault.yml
ansible-vault edit inventories/hrlv-dev/group_vars/all/vault.yml

# Install collections
ansible-galaxy collection install -r collections/requirements.yml
```

## Key Files

- `inventories/hrlv-dev/hosts.yml` — All hosts, groups, and connection vars
- `inventories/hrlv-dev/group_vars/all/vault.yml` — Encrypted secrets (vault)
- `inventories/hrlv-dev/group_vars/ue.yml` — UE paths, Plastic, worker config
- `playbooks/site.yml` — Master convergence playbook
- `playbooks/deploy.yml` — Day-to-day Plastic sync + worker deploy
- `scripts/bootstrap-ansible.ps1` — Run once per Windows VM via Proxmox console

## Adding a New Node

```bash
# Windows VM:
# 1. Create VM in Proxmox
# 2. Run scripts/bootstrap-ansible.ps1 via Proxmox console
# 3. Add to inventories/hrlv-dev/hosts.yml under ue or arnold_fusion
# 4. ansible-playbook playbooks/site.yml --limit <hostname>

# LXC container:
# 1. Create LXC in Proxmox, add SSH key
# 2. Add to inventories/hrlv-dev/hosts.yml under rship
# 3. ansible-playbook playbooks/site.yml --limit <hostname>

# Linux VM:
# 1. Create VM in Proxmox, add SSH key
# 2. Add to inventories/hrlv-dev/hosts.yml under appropriate group
# 3. ansible-playbook playbooks/site.yml --limit <hostname>
```

## Secrets

Managed via Ansible Vault in `inventories/hrlv-dev/group_vars/all/vault.yml`. Vault password stored in `.vault_pass` (gitignored). Variables are prefixed `vault_` and referenced from plain-text vars files.

## Conventions

- Roles are composable layers — a node's identity is defined by which roles it gets
- `rivermax` is a host var (bool), not a group — applied conditionally with `when: rivermax | default(false)`
- Windows playbooks use `ansible.windows.*` modules
- Linux playbooks use `ansible.builtin.*` modules
- All secrets go through vault, never env vars or plaintext
- **WinRM runs in Session 0 (isolated service session)** — NOT the interactive desktop. Anything session-scoped (mapped drives, NFS mounts, env vars, GPU/display access) will be invisible to the logged-in user if done through `win_shell`. Use scheduled tasks targeting the interactive session for anything the desktop user needs to see. The `render_worker` and `smb_share` roles do this correctly.
