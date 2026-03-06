# OpenShift Virtualization Migration Guide

Migration path from Proxmox to Red Hat OpenShift Virtualization for Pulse infrastructure.

## Current State: Proxmox

### Hardware
- **Server**: Gigabyte G493-ZB1-AAP1 (R113-C10 variant)
- **CPU**: AMD EPYC 4004 series
- **GPUs**: 8x NVIDIA RTX 6000 Ada (PCI IDs: 10de:26b1, 10de:22ba)
- **NICs**: 2x Mellanox ConnectX-6 (MCX654106A-HCA_Ax, dual-port QSFP56)
- **Additional**: BlueField-2 integrated ConnectX-6 Dx

### Current Configuration

#### BIOS (MZB3-G41-000, R02_F24)
- Advanced → CPU Configuration → SVM Mode: **Enabled**
- AMD CBS → NBIO Common Options → IOMMU: **Enabled**

#### Proxmox Host
- GRUB: `amd_iommu=on iommu=pt`
- VFIO modules loaded for GPU passthrough
- NVIDIA drivers blacklisted on host
- 165+ IOMMU groups (excellent isolation)

#### GPU Passthrough
- All 8 GPUs bound to vfio-pci driver
- Device IDs: `10de:26b1` (VGA), `10de:22ba` (Audio)
- Passed through via `--hostpci0 XX:00,pcie=1,rombar=0`

#### ConnectX-6 SR-IOV
- Firmware configured: Ethernet mode, SR-IOV enabled, 8 VFs per port
- Switchdev mode enabled via udev rules
- OVS bridges (vmbr1, vmbr2) with LACP bonding
- VF representors added to OVS for hardware offload
- VFs passed through to VMs for RDMA/GPUDirect

---

## Target State: OpenShift Virtualization

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    OpenShift Cluster                            │
├─────────────────────────────────────────────────────────────────┤
│  Control Plane (3 nodes)                                        │
│  ├── API Server, etcd, Controllers                              │
│  └── Operators: HyperConverged, GPU, SR-IOV, Node Tuning        │
├─────────────────────────────────────────────────────────────────┤
│  Worker Nodes (GPU-enabled)                                     │
│  ├── KubeVirt (virt-handler, virt-launcher)                     │
│  ├── VFIO Manager (GPU passthrough)                             │
│  ├── SR-IOV Device Plugin (NIC VFs)                             │
│  └── Node Feature Discovery                                     │
├─────────────────────────────────────────────────────────────────┤
│  VMs (as Kubernetes resources)                                  │
│  ├── Optik nodes (EVT cameras, GPU-direct, PTP)                 │
│  ├── Unreal nodes (graphics rendering)                          │
│  ├── Inference nodes (AI/ML)                                    │
│  └── Control nodes                                              │
└─────────────────────────────────────────────────────────────────┘
```

### Key Operators

| Operator | Purpose | Replaces (Proxmox) |
|----------|---------|-------------------|
| OpenShift Virtualization (HCO) | VM lifecycle, KubeVirt | qm CLI, Proxmox UI |
| NVIDIA GPU Operator | GPU drivers, device plugins | Manual vfio-pci binding |
| SR-IOV Network Operator | NIC VF management | Manual mlxconfig, udev rules |
| Node Tuning Operator | Kernel params, hugepages | Manual sysctl configs |
| Node Feature Discovery | Hardware detection | Manual lspci queries |

---

## Migration Mapping

### Layer-by-Layer Comparison

#### 1. BIOS/Firmware (No Change)
Both platforms require:
- IOMMU enabled (AMD-Vi / Intel VT-d)
- SR-IOV capable NICs with firmware configured
- ConnectX-6 in Ethernet mode with VFs enabled

#### 2. Host Kernel Configuration

| Setting | Proxmox | OpenShift |
|---------|---------|-----------|
| IOMMU | GRUB cmdline | MachineConfig |
| Hugepages | /etc/sysctl.d/ | Node Tuning Operator / PerformanceProfile |
| VFIO modules | /etc/modules-load.d/ | GPU Operator (automatic) |
| Driver blacklist | /etc/modprobe.d/ | GPU Operator (automatic) |

**OpenShift MachineConfig for IOMMU:**
```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 100-worker-iommu
spec:
  kernelArguments:
    - amd_iommu=on
    - iommu=pt
```

#### 3. GPU Passthrough

| Aspect | Proxmox | OpenShift |
|--------|---------|-----------|
| Driver binding | Manual vfio-pci config | GPU Operator VFIO Manager |
| Device discovery | lspci, manual config | Node Feature Discovery |
| VM assignment | hostpci0 in VM config | HyperConverged CR permittedHostDevices |
| Node selection | N/A (single host) | Node labels: `nvidia.com/gpu.workload.config=vm-passthrough` |

**OpenShift HyperConverged CR for GPU passthrough:**
```yaml
apiVersion: hco.kubevirt.io/v1beta1
kind: HyperConverged
metadata:
  name: kubevirt-hyperconverged
  namespace: openshift-cnv
spec:
  permittedHostDevices:
    pciHostDevices:
      - pciDeviceSelector: "10DE:26B1"  # RTX 6000 Ada VGA
        resourceName: "nvidia.com/RTX6000ADA"
        externalResourceProvider: true
      - pciDeviceSelector: "10DE:22BA"  # RTX 6000 Ada Audio
        resourceName: "nvidia.com/RTX6000ADA_AUDIO"
        externalResourceProvider: true
```

**Limitation**: A worker node can run GPU containers OR GPU-passthrough VMs OR vGPU VMs, but NOT mixed workloads.

#### 4. ConnectX-6 SR-IOV

| Aspect | Proxmox | OpenShift |
|--------|---------|-----------|
| VF creation | mlxconfig + udev rules | SriovNetworkNodePolicy |
| Switchdev mode | devlink via udev | SriovNetworkNodePolicy eSwitchMode |
| OVS integration | Manual /etc/network/interfaces | OVN-Kubernetes (default) or OVS via NMState |
| VF passthrough | Manual PCI device in VM | SriovNetwork + pod/VM annotation |
| RDMA | Manual in guest | isRdma: true in policy |

**OpenShift SriovNetworkNodePolicy for ConnectX-6:**
```yaml
apiVersion: sriovnetwork.openshift.io/v1
kind: SriovNetworkNodePolicy
metadata:
  name: cx6-sriov-policy
  namespace: openshift-sriov-network-operator
spec:
  deviceType: netdevice
  isRdma: true
  linkType: eth
  mtu: 9000
  nicSelector:
    vendor: "15b3"
    deviceID: "101b"  # ConnectX-6
  nodeSelector:
    feature.node.kubernetes.io/network-sriov.capable: "true"
  numVfs: 8
  priority: 99
  resourceName: mellanoxvf
```

**Note**: Mellanox NICs require node reboot when increasing VF count.

#### 5. VM Configuration

| Aspect | Proxmox | OpenShift |
|--------|---------|-----------|
| VM definition | qm create / .conf files | VirtualMachine CRD (YAML) |
| Storage | ZFS-Data, local-lvm | PersistentVolumeClaim (CSI) |
| Networking | virtio + bridge | Multus CNI + SR-IOV |
| Guest agent | qemu-guest-agent | qemu-guest-agent (same) |
| Live migration | pvecm | KubeVirt LiveMigration |

**OpenShift VirtualMachine with GPU passthrough:**
```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: optik-node-01
spec:
  running: true
  template:
    spec:
      domain:
        devices:
          gpus:
            - name: gpu0
              deviceName: nvidia.com/RTX6000ADA
          interfaces:
            - name: sriov-net
              sriov: {}
        resources:
          requests:
            memory: 128Gi
      networks:
        - name: sriov-net
          multus:
            networkName: cx6-sriov-network
      volumes:
        - name: rootdisk
          persistentVolumeClaim:
            claimName: optik-node-01-rootdisk
```

#### 6. Guest-Level Configuration (Unchanged)

These scripts from pulse-deploy still apply inside the VM:
- **PTP**: linuxptp build and ptp4l.service (Symmetricom S300 compatibility)
- **Hugepages**: May be handled by Node Tuning Operator at host level instead
- **EVT network**: NetworkManager configuration for camera subnet
- **NVIDIA drivers**: Install inside VM (GPU Operator doesn't manage guest drivers)

---

## Migration Checklist

### Phase 1: OpenShift Installation
- [ ] Hardware validation (IOMMU groups, NIC firmware)
- [ ] OpenShift 4.17+ bare-metal installation (3 control + N worker)
- [ ] MachineConfig for IOMMU kernel args
- [ ] Verify Node Feature Discovery detects GPUs and NICs

### Phase 2: Operator Installation
- [ ] Install OpenShift Virtualization Operator (HCO)
- [ ] Install NVIDIA GPU Operator
- [ ] Install SR-IOV Network Operator
- [ ] Install Node Tuning Operator (if not default)

### Phase 3: Hardware Configuration
- [ ] Label GPU worker nodes: `nvidia.com/gpu.workload.config=vm-passthrough`
- [ ] Create SriovNetworkNodePolicy for ConnectX-6
- [ ] Create SriovNetwork for VM attachment
- [ ] Configure HyperConverged CR with permitted GPU devices
- [ ] Verify VFIO binding and VF creation

### Phase 4: VM Migration
- [ ] Export Proxmox VM disks (qcow2 or raw)
- [ ] Import to OpenShift via CDI (Containerized Data Importer)
- [ ] Create VirtualMachine CRDs with GPU and SR-IOV attachments
- [ ] Test PTP, EVT camera connectivity inside VMs
- [ ] Validate GPU-direct / RDMA performance

### Phase 5: GitOps Integration
- [ ] Store VM definitions in Git
- [ ] Configure ArgoCD for VM lifecycle
- [ ] Implement node role profiles (optik, unreal, inference, control)
- [ ] CI/CD for guest image updates

---

## What Changes, What Stays

### Changes (Operator-Managed)
| Component | Proxmox (Manual) | OpenShift (Declarative) |
|-----------|------------------|------------------------|
| GPU binding | /etc/modprobe.d/vfio.conf | GPU Operator |
| VF creation | udev rules + mlxconfig | SriovNetworkNodePolicy |
| VM lifecycle | qm CLI | VirtualMachine CRD |
| Networking | OVS + /etc/network/interfaces | OVN-K + Multus + NMState |
| Storage | ZFS manual | CSI + PVC |
| Monitoring | External | Prometheus (built-in) |

### Stays the Same (Guest-Level)
| Component | Notes |
|-----------|-------|
| PTP (linuxptp) | Still needed for Symmetricom S300 compatibility |
| NVIDIA guest drivers | GPU Operator doesn't install inside VMs |
| EVT camera network config | NetworkManager inside guest |
| Application deployment | Unchanged inside VM |

### New Capabilities
| Capability | Description |
|------------|-------------|
| GitOps for VMs | VMs as code, ArgoCD managed |
| Mixed workloads | VMs and containers in same cluster |
| Horizontal scaling | Add nodes, Kubernetes schedules |
| Self-healing | Operator reconciliation |
| Unified observability | Prometheus, Grafana, alerts |

---

## References

### Red Hat Documentation
- [OpenShift Virtualization 4.17](https://docs.redhat.com/en/documentation/openshift_container_platform/4.17/html/virtualization/about)
- [SR-IOV Network Operator](https://docs.redhat.com/en/documentation/openshift_container_platform/4.17/html/hardware_networks/configuring-sriov-device)
- [DPDK and RDMA](https://docs.redhat.com/en/documentation/openshift_container_platform/4.17/html/hardware_networks/using-dpdk-and-rdma)

### NVIDIA Documentation
- [GPU Operator with OpenShift Virtualization](https://docs.nvidia.com/datacenter/cloud-native/openshift/latest/openshift-virtualization.html)
- [GPU Operator 24.9.1](https://docs.nvidia.com/datacenter/cloud-native/openshift/24.9.1/openshift-virtualization.html)

### Community Resources
- [KubeVirt User Guide](https://kubevirt.io/user-guide/)
- [Mellanox SR-IOV on OpenShift](https://github.com/openshift/sriov-network-operator)
