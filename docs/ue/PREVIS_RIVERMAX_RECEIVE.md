# Receiving Rivermax Streams in HRLV_Previs

Step-by-step guide for setting up Rivermax stream reception in the previs
project and displaying nDisplay output on the virtual LED volume mesh.

Sources:
- https://dev.epicgames.com/documentation/en-us/unreal-engine/smpte-2110-media-io-workflows-in-unreal-engine
- https://dev.epicgames.com/documentation/en-us/unreal-engine/ndisplay-workflows-for-smpte-2110-in-unreal-engine
- https://dev.epicgames.com/documentation/en-us/unreal-engine/smpte-2110-ux-reference-in-unreal-engine
- https://dev.epicgames.com/documentation/en-us/unreal-engine/supporting-multiple-media-configurations-in-unreal-engine
- https://dev.epicgames.com/documentation/en-us/unreal-engine/media-folder-structure-in-unreal-engine
- https://dev.epicgames.com/documentation/en-us/unreal-engine/troubleshooting-smpte-2110-in-unreal-engine

---

## Prerequisites

- NVIDIA Rivermax plugin enabled: **Edit > Plugins > "NVIDIA Rivermax Media Streaming"**
- Rivermax SDK + license installed on the previs machine
- Project Settings > Plugins > NVIDIA Rivermax:
  - **Time Source**: `System` (no BlueField-2 DPU on previs node)
  - **PTP Interface Address**: leave default (not used with System time source)

## Folder Structure

```
Content/
  HRLV_Previs/
    Media/
      MediaProfiles/
        MPR_Rivermax_4Node
        MPR_Rivermax_1Node
      MediaSources/
        RMS_Zone1
        RMS_Zone2
        RMS_Zone3
        RMS_Zone4
        RMS_FullWall
      Players/
        MP_Zone1
        MP_Zone2
        MP_Zone3
        MP_Zone4
        MP_FullWall
      Textures/
        MT_Zone1
        MT_Zone2
        MT_Zone3
        MT_Zone4
        MT_FullWall
      Materials/
        M_LEDInput_Zone
        M_LEDInput_FullWall
```

---

## Step 1: Create Rivermax Media Sources (one per stream)

Content Browser > Right-click > **Media > Rivermax Media Source**

Create one per zone. For the 4-node config:

| Asset | Interface Address | Stream Address | Port | Notes |
|-------|------------------|----------------|------|-------|
| RMS_Zone1 | 10.10.20.* | 225.1.2.1 | 50000 | Match nDisplay node 1 output |
| RMS_Zone2 | 10.10.20.* | 225.1.2.2 | 50000 | Match nDisplay node 2 output |
| RMS_Zone3 | 10.10.20.* | 225.1.2.3 | 50000 | Match nDisplay node 3 output |
| RMS_Zone4 | 10.10.20.* | 225.1.2.4 | 50000 | Match nDisplay node 4 output |

> **Note**: Interface Address and Stream Address must match the nDisplay
> Media Output config on the content nodes. Wildcard `*` supported for
> multi-machine flexibility.

### Rivermax Media Source Settings

| Field | Value | Notes |
|-------|-------|-------|
| Resolution | Unchecked | Auto-detect from RTP headers |
| Frame Rate | 60 | Must match sender |
| Pixel Format | RGB10bit | Must match sender |
| Interface Address | 10.10.20.* | Previs node's CX6 VF IP |
| Stream Address | (per zone, see above) | Multicast group |
| Port | 50000 | Match sender |

### Synchronization Settings

| Field | Value | Notes |
|-------|-------|-------|
| Time Synchronization | Enabled | Required for Rivermax |
| Frame Delay | 0 | Rivermax always uses latest frame |
| Sample Evaluation Type | Timecode | Required for Rivermax |
| Framelock | Enabled | Match sender/receiver frame numbers (UE-to-UE) |
| Use Zero Latency | Optional | Matches frames with no added delay; may need 1 frame buffer for reliability |

### Advanced

| Field | Value | Notes |
|-------|-------|-------|
| Use GPU Direct | false | Unless GPU and CX6 share IOMMU group |

## Step 2: Create Media Players + Media Textures

For each zone:

1. Content Browser > Right-click > **Media > Media Player**
2. In the dialog, check **"Create linked assets"** — this auto-generates a Media Texture
3. Name them consistently: `MP_Zone1` creates `MT_Zone1`
4. Open the Media Player asset, set its source to the matching `RMS_Zone*`

Repeat for each zone (4x for 4-node, 1x for single-node).

## Step 3: Create Materials

1. Content Browser > Right-click > **Material**
2. In the Material Editor:
   - Add a **Texture Sample** node
   - Set its **Texture** to the corresponding `MT_Zone*`
   - Set **Sampler Type** to `External`
   - Connect to **Emissive Color** (not Base Color — LED panels emit light)
   - Material Domain: Surface
   - Shading Model: Unlit (LED wall emits, doesn't receive lighting)
3. Apply material to the corresponding LED zone mesh actor in the level

### For parameterized approach (optional)

Create one master material `M_LEDInput` with a Texture Parameter instead
of a direct texture reference. Create Material Instances per zone, each
pointing to its `MT_Zone*`. This is cleaner if zones share the same
material setup.

## Step 4: Create Media Profiles

Content Browser > Right-click > **Media > Media Profile**

### MPR_Rivermax_4Node

Add 4 Media Source entries:
- Index 0: RMS_Zone1
- Index 1: RMS_Zone2
- Index 2: RMS_Zone3
- Index 3: RMS_Zone4

### MPR_Rivermax_1Node

Add 1 Media Source entry:
- Index 0: RMS_FullWall

### Activate

Project Settings > Plugins > Media Profile > set the active profile.
Or switch via the toolbar dropdown in the editor.

## Step 5: Level Setup

1. Place mesh actors representing each LED zone in the previs level
2. Assign the corresponding zone material to each mesh
3. For single-node config: one full-wall mesh with `M_LEDInput_FullWall`
4. Toggle visibility between 4-zone and 1-zone mesh groups based on
   active Media Profile (Blueprint or manual)

## Quick Preview (skip material setup)

Open any `RMS_Zone*` asset in the Content Browser and click **Open** in
the menu bar to preview the stream directly in the asset editor.

---

## Troubleshooting

### Stream not showing

- Verify multicast address + port match between sender and receiver
- Check Windows firewall allows inbound UDP on the media port
- Verify CX6 adapter is visible: `Get-NetAdapter | Where InterfaceDescription -like '*Mellanox*'`
- Check Rivermax license: `RIVERMAX_LICENSE_PATH` env var must be set

### Wrong colors (rainbow output)

Run on the node:
```
mlxconfig.exe q | findstr "FLEX_PARSER_PROFILE_ENABLE PROG_PARSE_GRAPH"
```
Both values must match. Mismatch = color parsing broken.

### CUDA / GPUDirect error

Set `RIVERMAX_ENABLE_CUDA=1` system env var if using GPUDirect.
If not using GPUDirect, set to `0` (our default via Ansible).

### ConnectX-6 (no BlueField-2) error status 13

Project Settings > Plugins > NVIDIA Rivermax > **Time Source**: set to
`System` instead of `PTP`. PTP time source requires BlueField-2 DPU.

### Tearing

Validate PTP sync across all nodes. All must share the same grandmaster
clock identity (`gmIdentity`).

### Non-standard resolutions (UE 5.3-5.4)

May cause inter-packet jitter with uneven packet sizes. Disable with:
```
Rivermax.Output.EnableMultiSRD=0
```
