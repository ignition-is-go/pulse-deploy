# Rivermax / SMPTE 2110 / nDisplay Reference

## Compatibility Matrix (UE 5.7)

| Component    | Version      | Notes                                  |
|--------------|--------------|----------------------------------------|
| Rivermax SDK | 1.71.30      | Must match UE 5.7 requirements exactly |
| WinOF-2      | 24.10.50010  | Range: 24.10.50010 — 25.7.50000       |
| UE           | 5.7          | SMPTE 2110 via nDisplay Media Output   |

Epic ref: https://dev.epicgames.com/documentation/en-us/unreal-engine/setting-up-smpte-2110-in-unreal-engine

## Networks

- **Management**: `192.168.1.0/24` — WinRM, SSH, general traffic.
- **2110 (media)**: `10.0.0.0/24` — SMPTE 2110 streams over CX6 SR-IOV VFs. No gateway, no DNS.
- **SMB (storage)**: `10.0.1.0/24` — SMB Direct over CX6 SR-IOV VFs. No gateway, no DNS.

Last octet mirrors management IP across all three networks.

## Rivermax Role (`roles/rivermax`)

Conditionally applied when `rivermax: true` (set in group vars).

1. WinOF-2 install — version-checked, silent with `/v"MT_RIVERMAX=1"`, reboots if needed
2. Rivermax SDK install — version-checked, extracted from zip, MSI install
3. License deploy — copied to `C:\Program Files\Mellanox\Rivermax\lib\rivermax.lic`
4. Environment variables (machine-level):

| Variable                 | Value                                              |
|--------------------------|----------------------------------------------------|
| `RIVERMAX_PATH_1_71_30`  | `C:\Program Files\Mellanox\Rivermax`               |
| `RIVERMAX_LICENSE_PATH`  | `C:\Program Files\Mellanox\Rivermax\lib\rivermax.lic` |
| `RIVERMAX_ENABLE_CUDA`   | `1`                                                |

5. Strict validation — fails if versions mismatch, DLL missing, license missing, or no CX6 adapter

GPUDirect RDMA not supported on SR-IOV VFs — `rivermax_gpudirect: false`.

Installers on deploy share:
```
\\192.168.1.31\share\rivermax\
    MLNX_WinOF2-24_10_50010_All_x64.exe
    Rivermax_Windows_1.71.30.zip
    Rivermax-12022026-qty3-1a7da843cfd1.lic
```

## CX6 SR-IOV

Each GPU VM gets two CX6 VFs passed through from Proxmox host:
- **VF 0** (higher PCI bus) = 2110 media
- **VF 1** (lower PCI bus) = SMB storage

See `docs/proxmox/connectx6-sriov.md` for host-side setup. Requires `VF_VPD_ENABLE=1`
firmware setting for Rivermax license validation in VMs.

## nDisplay CLI Launch

Source: reverse-engineered from Switchboard listener output.
Epic Forums: https://forums.unrealengine.com/t/how-to-run-ndisplay-by-script-or-command-line/479685

Epic does NOT publish raw CLI args — they are abstracted behind Switchboard and nDisplay Quick Launch UI.

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

### Critical args

1. **`-dc_dev_mono`** — rendering device type, required
2. **`-ini:Input:...DefaultPlayerInputClass`** — without this, mouse controls camera
3. **`-ini:Engine:`** — must have BOTH `GameEngine` AND `GameViewportClientClassName` on same arg, comma-separated

### .ndisplay config

- `-dc_cfg` only accepts `.ndisplay` or `.cfg` files, NOT `.uasset`
- `bOverrideViewportsFromExternalConfig` / `bOverrideTransformsFromExternalConfig` — use viewport/transform from file instead of DCRA in level
- Mesh projection requires DCRA in level regardless (mesh geometry from actor components)

### Launch mechanism

WinRM runs in Session 0 (no GPU access). Launch requires:
1. Ansible writes `C:\ndisplay-launch.bat` with full command line
2. Scheduled task (`nDisplayLaunch`) with `interactive_token` logon (Session 1)
3. Task triggered immediately, playbook waits for UnrealEditor process

### nDisplay configs (selectable via `-e "ndisplay=..."`)

| Key              | Config file                                          |
|------------------|------------------------------------------------------|
| `rivermax_4node` | `nDisplayConfig_Rivermax_4Node.ndisplay` (default)   |
| `rivermax_1node` | `nDisplayConfig_Rivermax_1Node.ndisplay`             |
| `ndi_4node`      | `nDisplayConfig_NDI_4Node.ndisplay`                  |

## SMPTE 2110 Stream Config (TODO)

Epic ref: https://dev.epicgames.com/documentation/en-us/unreal-engine/ndisplay-workflows-for-smpte-2110-in-unreal-engine

Each nDisplay node needs a Media Output with:
- Unique multicast address per node (225.0.0.{octet}, port 50000)
- Interface address = node's 2110 IP (10.0.0.x)
- Pixel format, frame rate, capture sync TBD

Outstanding:
- Mellanox switch IGMP snooping / multicast routing config
- Configure Media Output assets per content node
- Set up receiver-side Media Source on previs node
- Validate end-to-end stream delivery
- Consider Ansible automation (may require UE Python scripting)
