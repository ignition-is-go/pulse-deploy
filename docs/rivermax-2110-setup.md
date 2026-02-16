# Rivermax / SMPTE 2110 / nDisplay Setup Guide

Comprehensive reference for the HRLV render farm's Rivermax, SMPTE 2110, and nDisplay
cluster configuration. Covers architecture, deploy infrastructure, driver/SDK install,
CX6 media networking, and nDisplay command-line launch.

---

## 1. Architecture Overview

The HRLV render farm runs on Proxmox, with Windows VMs for Unreal Engine rendering
and a Linux LXC container (pulse-admin) as the Ansible control plane and deploy
file server.

### Fleet

| Hostname                    | Management IP   | Media IP   | Role                       | Group           |
|-----------------------------|-----------------|------------|----------------------------|-----------------|
| windows-unreal-render-01    | 192.168.1.71    | 10.0.0.1   | nDisplay Node_1 (primary)  | content_nodes   |
| windows-unreal-render-02    | 192.168.1.72    | 10.0.0.2   | nDisplay Node_2            | content_nodes   |
| windows-unreal-render-03    | 192.168.1.73    | 10.0.0.3   | nDisplay Node_3            | content_nodes   |
| windows-unreal-render-04    | 192.168.1.74    | 10.0.0.4   | nDisplay Node_4            | content_nodes   |
| windows-unreal-render-05    | 192.168.1.75    | 10.0.0.5   | Previs render node         | previs_nodes    |
| windows-touch-01            | 192.168.1.76    | 10.0.0.6   | Touch Designer node        | touch_nodes     |
| ue-control-plane-01         | 192.168.1.168   | --         | Ansible control plane      | manager         |
| pulse-admin (LXC)           | 192.168.1.70    | --         | Deploy share / Samba       | (Proxmox LXC)  |

### Networks

- **Management network**: `192.168.1.0/24` -- standard VM traffic, WinRM, SSH.
- **Media network**: `10.0.0.0/24` -- SMPTE 2110 media streams over ConnectX-6 VFs.
  Isolated from management traffic. No gateway, no DNS.

### Connection methods

- Windows VMs: WinRM on port 5985, NTLM auth.
- Linux VMs / LXC: SSH.
- Control plane: local connection.

---

## 2. SMB Deploy Share

Installers and license files are served from an SMB share on the pulse-admin LXC
container. This avoids copying large binaries through the Ansible control connection.

### Host

- **Container**: pulse-admin LXC on Proxmox host `nyc-dev-pve-03`
- **IP**: 192.168.1.70

### Storage

- **ZFS dataset**: `zfs-nvme-05/deploy` on the Proxmox host
- **Bind mount into LXC**:
  ```bash
  pct set <CTID> -mp0 /zfs-nvme-05/deploy,mp=/mnt/deploy
  ```

### Samba configuration

The Samba share is configured for guest access (no authentication required from
the render nodes):

Global section (already present in default smb.conf):
```ini
   map to guest = bad user
```

Share definition (appended to smb.conf):
```ini
[deploy]
   path = /mnt/deploy
   browseable = yes
   read only = no
   guest ok = yes
   force user = nobody
   create mask = 0664
   directory mask = 0775
```

### UNC path

```
\\192.168.1.70\deploy
```

Referenced in Ansible as the `deploy_share` variable, defined in
`inventories/hrlv/group_vars/all/main.yml`:

```yaml
deploy_share: "\\\\192.168.1.70\\deploy"
```

### Contents (rivermax subfolder)

```
\\192.168.1.70\deploy\rivermax\
    MLNX_WinOF2-24_10_50010_All_x64.exe     # WinOF-2 driver installer
    Rivermax_Windows_1.71.30.zip             # Rivermax SDK archive
    Rivermax-12022026-qty3-1a7da843cfd1.lic  # Rivermax license (3 seats)
```

These files are gitignored (`*.exe`, `*.zip`, `*.lic` patterns in `.gitignore`).

---

## 3. Rivermax / SMPTE 2110 Setup

### Reference

Epic documentation:
https://dev.epicgames.com/documentation/en-us/unreal-engine/setting-up-smpte-2110-in-unreal-engine

### Compatibility matrix (UE 5.7 + BlueField-2 / ConnectX-6)

| Component      | Version          | Notes                                   |
|----------------|------------------|-----------------------------------------|
| Rivermax SDK   | 1.71.30          | Must match UE 5.7 requirements exactly  |
| WinOF-2        | 24.10.50010      | Range: 24.10.50010 -- 25.7.50000        |
| UE             | 5.7              | SMPTE 2110 via nDisplay Media Output     |

### Environment variables

Set as machine-level system environment variables by the Ansible role:

| Variable                     | Value                                                 |
|------------------------------|-------------------------------------------------------|
| `RIVERMAX_PATH_1_71_30`     | `C:\Program Files\Mellanox\Rivermax`                  |
| `RIVERMAX_LICENSE_PATH`     | `C:\Program Files\Mellanox\Rivermax\lib\rivermax.lic` |
| `RIVERMAX_ENABLE_CUDA`      | `1`                                                   |

### Ansible role: `roles/rivermax`

The role is a Layer 1 driver role, applied conditionally when `rivermax: true` is
set as a host variable. It performs:

1. **WinOF-2 install** -- version-checked. Copies installer from deploy share, runs
   silent install with `/v"MT_RIVERMAX=1"`, reboots if needed.
2. **Rivermax SDK install** -- version-checked. Copies zip from deploy share, extracts,
   runs MSI installer.
3. **License deployment** -- copies license file to `C:\Program Files\Mellanox\Rivermax\lib\rivermax.lic`.
4. **Environment variables** -- sets the three env vars listed above.
5. **Strict validation** -- fails the play if:
   - WinOF-2 version does not match expected (`24.10.50010`)
   - Rivermax SDK version does not match expected (`1.71.30`)
   - `rivermax.dll` is missing from the install directory
   - License file is missing
   - No Mellanox/ConnectX adapter is detected
6. **Cleanup** -- removes temp installer files from `C:\temp`.

### Defaults (`roles/rivermax/defaults/main.yml`)

```yaml
rivermax_install_dir: 'C:\Program Files\Mellanox\Rivermax'
rivermax_installers_remote: true
rivermax_sdk_version: "1_71_30"
rivermax_sdk_version_dotted: "1.71.30"
rivermax_winof2_version: "24.10.50010"
```

### Installer paths (`inventories/hrlv/group_vars/windows.yml`)

```yaml
rivermax_winof2_installer: "{{ deploy_share }}\\rivermax\\MLNX_WinOF2-24_10_50010_All_x64.exe"
rivermax_sdk_installer: "{{ deploy_share }}\\rivermax\\Rivermax_Windows_1.71.30.zip"
rivermax_license_src: "{{ deploy_share }}\\rivermax\\Rivermax-12022026-qty3-1a7da843cfd1.lic"
```

### Running the role

```bash
# All rivermax-enabled Windows nodes
ansible-playbook playbooks/rivermax-setup.yml

# Content nodes only
ansible-playbook playbooks/rivermax-setup.yml --limit content_nodes

# Single node
ansible-playbook playbooks/rivermax-setup.yml --limit windows-unreal-render-01

# Dry run
ansible-playbook playbooks/rivermax-setup.yml --check
```

The role is also included in `playbooks/site.yml` for full convergence runs.

---

## 4. CX6 Media Network

### Hardware

Each render node has a ConnectX-6 Virtual Function (VF) passed through from the
Proxmox host via SR-IOV. See `docs/proxmox/CONNECTX6_SRIOV.md` for the SR-IOV setup,
including the required `VF_VPD_ENABLE=1` firmware setting for Rivermax license
validation in VMs.

### Playbook: `playbooks/cx6-ip.yml`

Configures a static IP on the ConnectX-6 VF adapter. Targets `ue_nodes` and
`touch_nodes`, filtered by `rivermax: true`.

The playbook:
1. Finds the Mellanox/ConnectX adapter (fails if zero or more than one found).
2. Removes any existing IP addresses and routes on that adapter.
3. Assigns the static IP from the `media_ip` host variable with `/24` prefix.
4. Disables DHCP on the adapter.
5. Displays the resulting IP configuration.

### IP assignments

| Hostname                    | Media IP   |
|-----------------------------|------------|
| windows-unreal-render-01    | 10.0.0.1   |
| windows-unreal-render-02    | 10.0.0.2   |
| windows-unreal-render-03    | 10.0.0.3   |
| windows-unreal-render-04    | 10.0.0.4   |
| windows-unreal-render-05    | 10.0.0.5   |
| windows-touch-01            | 10.0.0.6   |

### Running the playbook

```bash
ansible-playbook playbooks/cx6-ip.yml
ansible-playbook playbooks/cx6-ip.yml --limit windows-unreal-render-01
```

---

## 5. nDisplay Cluster

### Overview

The HRLV content cluster is a 4-node nDisplay setup using mesh projection. Each node
renders a 4096x988 viewport. The cluster is launched via command-line arguments,
without Switchboard.

### Configuration

- **UE version**: 5.7 (installed at `F:/Epic Games/UE_5.7/`)
- **Project**: `F:/P-0616-HRLV/ue/HRLV_Content/HRLV_Content.uproject`
- **nDisplay config file**: `F:/P-0616-HRLV/ue/HRLV_Content/Content/nDisplay/nDisplayConfig.ndisplay`
- **Map**: `/Game/HRLV_Content/Maps/Dev/LookDev/ColorCharts_v2` (configurable via `ndisplay_map`)
- **Primary node**: Node_1 (`windows-unreal-render-01`, 192.168.1.71)

### Cluster nodes

| Hostname                    | nDisplay Node | Primary? |
|-----------------------------|---------------|----------|
| windows-unreal-render-01    | Node_1        | Yes      |
| windows-unreal-render-02    | Node_2        | No       |
| windows-unreal-render-03    | Node_3        | No       |
| windows-unreal-render-04    | Node_4        | No       |

### Command-line launch args

Source: reverse-engineered from Switchboard listener output, confirmed on Epic Forums:
https://forums.unrealengine.com/t/how-to-run-ndisplay-by-script-or-command-line/479685

Epic does NOT publish raw CLI args -- they are abstracted behind Switchboard and the
nDisplay Quick Launch UI.

```
UnrealEditor.exe "Project.uproject"
  -game <map_path_or_None>
  -messaging
  -dc_cluster
  -dc_cfg="<path_to_.ndisplay_file>"
  -dc_node=<NodeName>
  -dc_dev_mono
  -ini:Engine:[/Script/Engine.Engine]:GameEngine=/Script/DisplayCluster.DisplayClusterGameEngine,[/Script/Engine.Engine]:GameViewportClientClassName=/Script/DisplayCluster.DisplayClusterViewportClient
  -ini:Game:[/Script/EngineSettings.GeneralProjectSettings]:bUseBorderlessWindow=True
  -ini:Input:[/Script/Engine.InputSettings]:DefaultPlayerInputClass=/Script/DisplayCluster.DisplayClusterPlayerInput
  -unattended
  -NoScreenMessages
  -nosplash
  -fixedseed
  -NoVerifyGC
  -noxrstereo
  -RemoteControlIsHeadless
  -StageFriendlyName="<NodeName>"
  Log=<NodeName>.log
```

### Critical args (easy to miss)

1. **`-dc_dev_mono`** -- sets the rendering device type.
2. **`-ini:Input:...DefaultPlayerInputClass`** -- without this, default PlayerInput
   remains active and mouse movement controls the camera.
3. **`-ini:Engine:`** -- must include BOTH `GameEngine` AND `GameViewportClientClassName`
   on the same `-ini:Engine:` argument, comma-separated.

### .ndisplay config notes

- `-dc_cfg` only accepts `.ndisplay` or `.cfg` files, NOT `.uasset`.
- `bOverrideViewportsFromExternalConfig` and `bOverrideTransformsFromExternalConfig`
  can be set to true to use viewport/transform config from the .ndisplay file
  instead of matching DCRA in level.
- Mesh projection requires DCRA in level regardless (mesh geometry comes from actor
  components).

### Launch mechanism

Due to the space in the UE install path (`F:/Epic Games/UE_5.7/`), a direct scheduled
task Execute/Arguments approach breaks. Instead:

1. Ansible writes a batch file to `C:\ndisplay-launch.bat` containing the full
   command line.
2. A scheduled task (`nDisplayLaunch`) is created with `interactive_token` logon
   (Session 1 for GPU access).
3. The task is triggered immediately.
4. The playbook waits up to 30 seconds for the UnrealEditor process to appear.

WinRM runs in Session 0 (isolated service session), so `interactive_token` logon
is required for anything that needs GPU or display access.

### Playbooks

**Start the cluster**:
```bash
ansible-playbook playbooks/ndisplay-start.yml

# With a different map
ansible-playbook playbooks/ndisplay-start.yml -e "ndisplay_map=/Game/Path/To/Map"
```

The start playbook runs `serial: 1` to launch nodes sequentially (primary first).

**Stop the cluster**:
```bash
ansible-playbook playbooks/ndisplay-stop.yml
```

Stops all UnrealEditor processes on content nodes and removes the scheduled task.

### Group vars

**`inventories/hrlv/group_vars/content_nodes.yml`**:
```yaml
unreal_project: "F:/P-0616-HRLV/ue/HRLV_Content/HRLV_Content.uproject"
ndisplay_map: "/Game/HRLV_Content/Maps/Dev/LookDev/ColorCharts_v2"
ndisplay_config: "F:/P-0616-HRLV/ue/HRLV_Content/Content/nDisplay/nDisplayConfig.ndisplay"
```

**`inventories/hrlv/group_vars/ue_nodes.yml`**:
```yaml
unreal_engine_dir: "F:/Epic Games/UE_5.7"
unreal_exe: "{{ unreal_engine_dir }}/Engine/Binaries/Win64/UnrealEditor.exe"
```

Node-specific vars (`ndisplay_node`, `ndisplay_primary`) are set per-host in
`inventories/hrlv/hosts.yml`.

---

## 6. SMPTE 2110 Stream Configuration (TODO)

This section covers the per-node Media Output configuration required to send
SMPTE 2110 video streams from the nDisplay cluster over the CX6 media network.
This has not been implemented yet.

### Reference

Epic documentation:
https://dev.epicgames.com/documentation/en-us/unreal-engine/ndisplay-workflows-for-smpte-2110-in-unreal-engine

### Per-node configuration

Each nDisplay node needs a Media Output configured in the UE editor with:

- **Unique multicast address** per node (e.g., 225.1.2.1, 225.1.2.2, 225.1.2.3, 225.1.2.4)
- **Interface address**: the node's `media_ip` (10.0.0.x) -- tells Rivermax which
  NIC to send streams on
- **Pixel format**: to be determined (likely PF_B8G8R8A8 or PF_A2B10G10R10)
- **Frame rate**: to be determined (likely 23.976, 29.97, or 59.94)
- **Capture sync**: GPU texture readback timing

### Planned multicast assignments

| Node   | Media IP  | Multicast Address | Port  |
|--------|-----------|-------------------|-------|
| Node_1 | 10.0.0.1  | 225.0.0.1         | 50000 |
| Node_2 | 10.0.0.2  | 225.0.0.2         | 50000 |
| Node_3 | 10.0.0.3  | 225.0.0.3         | 50000 |
| Node_4 | 10.0.0.4  | 225.0.0.4         | 50000 |

### Receiver

`windows-unreal-render-05` (192.168.1.75 / 10.0.0.5) is the previs node and
potential 2110 stream receiver. Receiver-side Media Source configuration in UE will
need matching multicast addresses and the local `media_ip` as the interface address.

### Outstanding work

- Configure Media Output assets in each content node's UE project
- Set multicast addresses, interface IPs, pixel format, frame rate
- Configure capture sync / genlock settings
- Set up receiver-side Media Source on render-05
- Validate end-to-end stream delivery
- Consider Ansible automation for Media Output config (may require UE Python scripting)

---

## 7. Key Changes Made

Summary of infrastructure changes made during this setup session.

### win_base role (`roles/win_base/tasks/main.yml`)
- **Removed OpenSSH installation** -- the fleet uses WinRM exclusively, OpenSSH was
  unnecessary overhead.
- **Fixed firewall rule profiles** -- changed from `any` (invalid in
  `community.windows.win_firewall_rule`) to explicit list: `domain`, `private`, `public`.

### site.yml
- **Removed `smb_share` role** from the base Windows play. SMB share mounting is
  handled differently now (deploy share is accessed directly via UNC path in role tasks).
- **Added `touch_nodes` play** to the Windows section.
- **Rivermax play targets `windows`** (not just `ue_nodes`), with `when: rivermax | default(false)`
  condition. This allows any Windows node (including touch nodes) to opt in via host var.

### Inventory (`inventories/hrlv/hosts.yml`)
- **Added `touch_nodes` group** under `windows` with `windows-touch-01`.
- **Added `media_ip` host vars** to all rivermax-enabled nodes.
- **Added `ndisplay_node` and `ndisplay_primary` host vars** to content nodes.

### Group vars
- **`inventories/hrlv/group_vars/all/main.yml`**: added `deploy_share` variable
  pointing to `\\192.168.1.70\deploy`.
- **`inventories/hrlv/group_vars/windows.yml`**: added Rivermax installer paths
  referencing the deploy share.
- **`inventories/hrlv/group_vars/ue_nodes.yml`**: removed old render SMB share
  variables (`smb_share_name`, `smb_server`, etc.) that are no longer used.

### .gitignore
- Added `*.lic` to prevent committing license files.
- Added `*.zip`, `*.tar.gz`, `*.exe` to prevent committing installer binaries.

### New playbooks
- **`playbooks/rivermax-setup.yml`** -- standalone Rivermax deploy playbook.
- **`playbooks/cx6-ip.yml`** -- CX6 VF static IP configuration.
- **`playbooks/ndisplay-start.yml`** -- launch nDisplay cluster via command line.
- **`playbooks/ndisplay-stop.yml`** -- stop nDisplay cluster.

### New role
- **`roles/rivermax`** -- Layer 1 role for WinOF-2 + Rivermax SDK + license,
  with version-checked install and strict validation.

---

## 8. Useful Commands

### Full convergence

```bash
# Everything
ansible-playbook playbooks/site.yml

# All Windows nodes
ansible-playbook playbooks/site.yml --limit windows

# Content nodes only
ansible-playbook playbooks/site.yml --limit content_nodes

# Single node
ansible-playbook playbooks/site.yml --limit windows-unreal-render-01

# Dry run
ansible-playbook playbooks/site.yml --check
```

### Rivermax deploy

```bash
# All rivermax-enabled nodes
ansible-playbook playbooks/rivermax-setup.yml

# Single node
ansible-playbook playbooks/rivermax-setup.yml --limit windows-unreal-render-01
```

### CX6 media IP

```bash
# All nodes
ansible-playbook playbooks/cx6-ip.yml

# Single node
ansible-playbook playbooks/cx6-ip.yml --limit windows-unreal-render-03
```

### nDisplay

```bash
# Start cluster
ansible-playbook playbooks/ndisplay-start.yml

# Start with different map
ansible-playbook playbooks/ndisplay-start.yml -e "ndisplay_map=/Game/Some/Other/Map"

# Stop cluster
ansible-playbook playbooks/ndisplay-stop.yml
```

### Ad-hoc checks

```bash
# Ping all Windows nodes
ansible windows -m ansible.windows.win_ping

# Check WinOF-2 version on all rivermax nodes
ansible ue_nodes -m ansible.windows.win_shell -a "Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object { \$_.DisplayName -like '*WinOF*' } | Select-Object DisplayVersion"

# Check Rivermax SDK version
ansible ue_nodes -m ansible.windows.win_shell -a "Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object { \$_.DisplayName -like '*Rivermax*' } | Select-Object DisplayVersion"

# Check Rivermax environment variables
ansible ue_nodes -m ansible.windows.win_shell -a "[Environment]::GetEnvironmentVariable('RIVERMAX_LICENSE_PATH','Machine')"

# Check CX6 adapter and media IP
ansible ue_nodes -m ansible.windows.win_shell -a "Get-NetAdapter | Where-Object { \$_.InterfaceDescription -like '*Mellanox*' } | Get-NetIPAddress -AddressFamily IPv4 | Select-Object IPAddress"

# Check if UE is running
ansible content_nodes -m ansible.windows.win_shell -a "Get-Process -Name UnrealEditor -ErrorAction SilentlyContinue | Select-Object Id, StartTime"

# DHCP renew on management adapter
ansible ue_nodes -m ansible.windows.win_shell -a "ipconfig /renew"

# Check connectivity between nodes on media network
ansible windows-unreal-render-01 -m ansible.windows.win_shell -a "Test-Connection 10.0.0.2 -Count 2"
```

### Vault

```bash
# Edit secrets
ansible-vault edit inventories/hrlv/group_vars/all/vault.yml

# Encrypt secrets file
ansible-vault encrypt inventories/hrlv/group_vars/all/vault.yml
```
