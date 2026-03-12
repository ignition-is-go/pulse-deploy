# ATS + ACS DirectTrans for GPUDirect P2P

Enables direct GPU↔NIC DMA through PEX890xx PCIe switches instead of
bouncing through the CPU root complex.

Two Ansible roles implement this:
- `pve_cx6_sriov` — enables ATS in CX6 firmware (`ATS_ENABLED=True`)
- `pve_setpci_acs` — sets ACS DirectTrans on PEX890xx ports post-boot

Ref: https://docs.nvidia.com/ai-enterprise/planning-resource/optimizing-vm-configuration-ai-inference/latest/appendix.html
Ref: https://docs.nvidia.com/deeplearning/nccl/user-guide/docs/troubleshooting.html#pci-access-control-services-acs

## What it does

### Step 1: ATS firmware on CX6 (`pve_cx6_sriov` role)

```
mlxconfig -d <CX6_PF> set ATS_ENABLED=True
# cold reboot required
```

Enables PCIe Address Translation Services on the NIC. Both PFs and VFs
advertise `ATSCtl: Enable+` after reboot. CX6 (non-Dx) supports this —
confirmed on prod-pve-01 (mt4123).

### Step 2: ACS DirectTrans on PEX switches (`pve_setpci_acs` role)

```
# Ref: setpci -s ${BDF} ECAP_ACS+0x6.w=0x5D
setpci -s <BDF> ECAP_ACS+0x6.w=005D
```

Applied to all Broadcom PEX890xx ports (vendor:device `1000:c030`) via
systemd oneshot (`pve-setpci-acs.service`). Runs before `pve-guests.service`.

ACS register value `005D` (binary `0101 1101`):

| Bit | Name | Value | Effect |
|-----|------|-------|--------|
| 0 | SrcValid | 1 | Source validation enabled |
| 1 | TransBlk | 0 | Translation blocking disabled |
| 2 | ReqRedir | 1 | P2P request redirect ON (preserves IOMMU groups) |
| 3 | CmpltRedir | 1 | P2P completion redirect ON (preserves IOMMU groups) |
| 4 | UpstreamFwd | 1 | Upstream forwarding enabled |
| 5 | EgressCtrl | 0 | Egress control disabled |
| 6 | DirectTrans | 1 | ATS-translated P2P bypasses redirect |

Only bit 6 (DirectTrans) changes from the default `001D`. ReqRedir +
CmpltRedir stay ON so IOMMU groups are unaffected.

## Verified on prod-pve-01 + prod-pve-02 (2026-03-12)

- ATS firmware: `ATS_ENABLED=True(1)` on all CX6 cards (both hosts)
- ATS PCIe capability: `ATSCtl: Enable+` on PFs and VFs
- ACS registers: `ACSCtl=005d` on all PEX890xx downstream ports
- `lspci -vvv` shows `DirectTrans+` on PEX ports
- IOMMU groups: identical to baseline (docs/proxmox/acs-p2p-baseline.md)
- VMs start normally with existing passthrough mappings
- GPUDirect RDMA: confirmed working (`RDMA is supported and enabled`)
- setpci with VMs running: safe (permissive change, isolation preserved)

## Throughput — 4K60 2110 simulation (cross-host)

`rdk_generic_sender` → `rdk_rtp_receiver`, GPUDirect (`--gpu-id 0`),
rate-limited to 11.88 Gbps (4K60 SMPTE 2110 uncompressed video rate),
1460-byte RTP payloads, `--packets 4` for rate limiter granularity.

**Cross-host**: ue-content-01 (prod-pve-01) → ue-previs-02 (prod-pve-02)

| Metric | Result |
|--------|--------|
| Target rate | 11.88 Gbps |
| Received rate | 11.88 Gbps |
| Packet loss | 0 |
| Bad RTP headers | 0 |
| GPUDirect | Enabled (both sides) |

Full line rate (unlimited, `--packets 4096`): ~69 Gbps both intra-host
and cross-host — bottlenecked by CX6 100GbE line rate, not PCIe path.

## Latency — ping-pong

`rdk_latency --mode pp --gpu-id 0 --disable-ts`, 30-second measurement.
Round-trip GPU↔GPU via GPUDirect RDMA — both sides allocate buffers in
CUDA memory, NIC DMA's directly to/from GPU without staging through
system RAM. Full path per hop:

```
GPU → PCIe → CX6 VF → OVS → CX6 PF → cable → switch → cable → CX6 PF → OVS → CX6 VF → PCIe → GPU
```

### Cross-host: ue-content-01 (prod-pve-01) ↔ ue-previs-02 (prod-pve-02)

3,469,968 samples:

| Percentile | Latency |
|------------|---------|
| P0.1 | 3,950 ns |
| P1 | 3,950 ns |
| P10 | 4,000 ns |
| P25 | 4,000 ns |
| **P50** | **4,050 ns** |
| P75 | 4,350 ns |
| P90 | 4,650 ns |
| **P99** | **5,250 ns** |
| P99.9 | 6,850 ns |
| P99.99 | 14,800 ns |
| Avg | 4,241 ns |
| Min | 3,850 ns |
| Max | 273,900 ns |

### Intra-host: ue-content-01 ↔ ue-content-02 (both on prod-pve-01)

Comparison between ACS default (`001d`) and DirectTrans (`005d`):

| Metric | 001d (no DirectTrans) | 005d (DirectTrans+) |
|--------|----------------------|---------------------|
| Avg | 3,635 ns | 3,622 ns |
| P50 | 3,500 ns | 3,450 ns |
| P99 | 4,600 ns | 4,600 ns |

Cross-host adds ~550 ns to P50 vs intra-host (4,050 vs 3,450 ns),
consistent with the additional switch + cable hops between hosts.

Intra-host `001d` vs `005d` are within noise — the expected improvement
from eliminating a root complex hop (~100-200ns) is below the measurement
resolution of software timestamps.

## Measurement limitations

### Why `--disable-ts` is required (no HW timestamps on VFs)

Our CX6 cards (mt4123, non-Dx) do not have the `REAL_TIME_CLOCK_ENABLE`
firmware parameter. This parameter exists on CX6 Dx and later — it
exposes a real-time clock (UTC/TAI format) that VFs can read without
driver translation. Without it, the only HW clock is the PF's free-running
clock, which VFs cannot access. Rivermax returns status 301
(`RMAX_ERR_HW_CLOCK_NOT_SUPPORTED`) and falls back to the system clock.

Even on CX6 Dx with `REAL_TIME_CLOCK_ENABLE`, VFs cannot *adjust* the
clock — the MLNX OFED docs state: "only physical functions are allowed
to modify the hardware real-time clock, so PTP daemon adjustments from
VFs will be treated as a NOP." NVIDIA's position on the developer forums
is "we do not test PTP on VMs" and recommends BlueField DPU instead.

Ref: https://docs.nvidia.com/networking/display/MLNXOFEDv543580/Time-Stamping
Ref: https://docs.nvidia.com/networking/display/nvidia5ttechnologyusermanualv10/real+time+clock
Ref: https://forums.developer.nvidia.com/t/ptp-on-sriov-vf-connect-x-6-dx/240097

### Consequence for measurement

- Software timestamps (~μs resolution) are too coarse to measure
  PCIe-level differences (~100-200ns per hop).
- Throughput at unlimited rate is bottlenecked by 100GbE line rate, not
  PCIe path — both `001d` and `005d` hit the same ~69 Gbps ceiling.

## Safety

- `setpci` changes are volatile — reboot restores defaults
- `pve_setpci_acs` role refuses to run if VMs are running on the host
- Systemd service runs before `pve-guests.service` on boot
- `0x005D` is NVIDIA's documented value for VM/passthrough environments
- Revert: `mlxconfig set ATS_ENABLED=False` + `systemctl disable pve-setpci-acs`

## Failed approaches (for reference)

- **`pci=config_acs=xx00xx1@pci:1000:c030` at boot**: Clears ReqRedir/CmpltRedir
  during PCI enumeration — broke IOMMU groups (devices merged into shared groups).
  Incompatible with `pcie_acs_override`. Reverted.
- **DirectTrans + GPU ATS**: RTX 6000 Ada does not support PCIe ATS. No discrete
  NVIDIA GPU on PCIe supports ATS — only Grace Hopper (NVLink-C2C) and V100 on
  POWER9 (NVLink 2.0). The `0x005D` approach works because only the NIC needs ATS.
- **`setpci 0x0000` (disable all ACS)**: NCCL bare-metal approach. Would break
  IOMMU isolation required for VFIO passthrough.
