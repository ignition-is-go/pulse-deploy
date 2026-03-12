# ACS P2P Baseline — Pre-change snapshot (2026-03-11)

Captured before applying `pci=config_acs=xx00xx1@pci:1000:c030` to enable
PCIe P2P direct transactions for GPUDirect RDMA.

## What to verify after reboot

1. IOMMU groups unchanged (same group numbers, same BDFs)
2. ACS registers show `0051` instead of `001d` on PEX890xx ports
3. VMs start normally with existing passthrough mappings
4. GPUDirect RDMA still works (RIVERMAX_ENABLE_CUDA=1)

## nyc-prod-pve-01

Kernel: 6.17.2-1-pve
GRUB: `quiet amd_iommu=on iommu=pt pci=realloc=on pcie_acs_override=downstream,multifunction nofb nomodeset video=vesafb:off,efifb:off`

### IOMMU groups (GPU + CX6 only)

```
group=48  bdf=0000:5a:00.0  CX6 PF0 (card 1)
group=49  bdf=0000:5a:00.1  CX6 PF1 (card 1)
group=50  bdf=0000:5b:00.0  RTX 6000 Ada (GPU 1)
group=51  bdf=0000:5b:00.1  RTX 6000 Ada Audio (GPU 1)
group=54  bdf=0000:5e:00.0  RTX 6000 Ada (GPU 2)
group=55  bdf=0000:5e:00.1  RTX 6000 Ada Audio (GPU 2)
group=60  bdf=0000:63:00.0  RTX 6000 Ada (GPU 3)
group=61  bdf=0000:63:00.1  RTX 6000 Ada Audio (GPU 3)
group=62  bdf=0000:64:00.0  RTX 6000 Ada (GPU 4)
group=63  bdf=0000:64:00.1  RTX 6000 Ada Audio (GPU 4)
group=139 bdf=0000:d6:00.0  RTX 6000 Ada (GPU 5)
group=140 bdf=0000:d6:00.1  RTX 6000 Ada Audio (GPU 5)
group=141 bdf=0000:d7:00.0  RTX 6000 Ada (GPU 6)
group=142 bdf=0000:d7:00.1  RTX 6000 Ada Audio (GPU 6)
group=145 bdf=0000:da:00.0  RTX 6000 Ada (GPU 7)
group=146 bdf=0000:da:00.1  RTX 6000 Ada Audio (GPU 7)
group=151 bdf=0000:df:00.0  CX6 PF0 (card 2)
group=152 bdf=0000:df:00.1  CX6 PF1 (card 2)
group=153 bdf=0000:e0:00.0  RTX 6000 Ada (GPU 8)
group=154 bdf=0000:e0:00.1  RTX 6000 Ada Audio (GPU 8)
group=183-214  CX6 VFs (5a:00.2 - 5a:02.1, df:00.2 - df:02.1)
```

Note: GPU VGA and Audio in SEPARATE groups (e.g. 50 vs 51).

### ACS registers (all PEX890xx ports)

All 24 ports: `ACSCtl=001d` (SrcValid + ReqRedir + CmpltRedir + UpstreamFwd)

## nyc-prod-pve-02

Kernel: 6.17.2-1-pve
GRUB: `amd_iommu=on iommu=pt`

### IOMMU groups (GPU + CX6 only)

```
group=44  bdf=0000:5a:00.0  CX6 PF0 (card 1)
group=45  bdf=0000:5a:00.1  CX6 PF1 (card 1)
group=46  bdf=0000:5b:00.0  RTX 6000 Ada (GPU 1)
group=46  bdf=0000:5b:00.1  RTX 6000 Ada Audio (GPU 1)
group=49  bdf=0000:5e:00.0  RTX 6000 Ada (GPU 2)
group=49  bdf=0000:5e:00.1  RTX 6000 Ada Audio (GPU 2)
group=54  bdf=0000:63:00.0  RTX 6000 Ada (GPU 3)
group=54  bdf=0000:63:00.1  RTX 6000 Ada Audio (GPU 3)
group=55  bdf=0000:64:00.0  RTX 6000 Ada (GPU 4)
group=55  bdf=0000:64:00.1  RTX 6000 Ada Audio (GPU 4)
group=127 bdf=0000:d6:00.0  RTX 6000 Ada (GPU 5)
group=127 bdf=0000:d6:00.1  RTX 6000 Ada Audio (GPU 5)
group=128 bdf=0000:d7:00.0  RTX 6000 Ada (GPU 6)
group=128 bdf=0000:d7:00.1  RTX 6000 Ada Audio (GPU 6)
group=131 bdf=0000:da:00.0  RTX 6000 Ada (GPU 7)
group=131 bdf=0000:da:00.1  RTX 6000 Ada Audio (GPU 7)
group=136 bdf=0000:df:00.0  CX6 PF0 (card 2)
group=137 bdf=0000:df:00.1  CX6 PF1 (card 2)
group=138 bdf=0000:e0:00.0  RTX 6000 Ada (GPU 8)
group=138 bdf=0000:e0:00.1  RTX 6000 Ada Audio (GPU 8)
group=167-198  CX6 VFs (5a:00.2 - 5a:02.1, df:00.2 - df:02.1)
```

Note: GPU VGA and Audio SHARE groups (e.g. both in 46). This host lacks
pcie_acs_override=downstream,multifunction — multifunction devices are grouped.

### ACS registers

All 24 ports: `ACSCtl=001d` (SrcValid + ReqRedir + CmpltRedir + UpstreamFwd)
