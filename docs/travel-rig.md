# Travel / Mockup Rig

Self-contained demo environment for on-site nDisplay deployments. Designed to operate fully air-gapped — no internet required.

## Hardware

| Device | Role | Notes |
|---|---|---|
| MikroTik ROSE (RDS2216) | Switch + NAS | RouterOS SMB deploy share, built-in 100G/25G/10G switching |
| Micro PC | PBS | Pre-loaded vzdump snapshots for fast restore on-site |
| PTP grandmaster | Clock source | Travel unit, model TBD |
| Render nodes | nDisplay cluster | Portable units, count varies by demo |

## Why this split

The ROSE combines switching and storage in one 1U box — ideal for travel. But it has no hot-swap drives (a drive failure resets the unit), so running PBS on it would put backups and networking in the same failure domain. A separate micro PC for PBS keeps those independent.

## Network topology

The ROSE replicates the production network in miniature using dedicated subnets with mirrored last octets — same mental model as production.

### Management — 192.168.2.0/24

Last octet mirrors production (192.168.1.x). Same host identity, different subnet.

```
.1        ROSE (gateway/switch)
.10       ROSE (NAS/SMB — same device, mgmt alias)
.31       Micro PC (PBS)
.151      Laptop / control node (Ansible)
.161-.164 Travel render nodes (ue-content)
```

### Media — 10.0.1.0/24

Separate from production media (10.0.0.0/24) to avoid collisions when validating in-building. Isolated, no gateway.

```
.161-.164 Travel render nodes (media NICs)
.250      Travel PTP grandmaster
```

### Port mapping (ROSE)

| Port type | Use | Network |
|---|---|---|
| 10GBase-T (2x) | Management uplinks, render nodes | 192.168.2.0/24 |
| 10G SFP+ (4x) | Additional management / PBS | 192.168.2.0/24 |
| 25G SFP28 (4x) | Media / Rivermax | 10.0.1.0/24 |
| 100G QSFP28 (2x) | Media uplink (if needed) | 10.0.1.0/24 |

## What lives where

| Content | Location | Purpose |
|---|---|---|
| Installers, drivers, UE content | ROSE SMB share | Same as production `deploy_share` |
| Node snapshots (vzdump) | Micro PC (PBS) | Restore any node without internet |
| Ansible codebase | Laptop or control LXC | `inventories/travel/` for travel-specific hosts/vars |

## Pre-trip checklist

1. Sync latest installers/content to ROSE deploy share
2. Run full `site.yml` convergence against travel nodes — verify clean
3. Take vzdump snapshots of all travel nodes → push to travel PBS
4. Validate nDisplay launch end-to-end on travel hardware
5. Pack and ship

## On-site recovery (no internet)

Worst case — node dies on-site:

1. Restore from travel PBS (minutes)
2. Re-converge with Ansible against ROSE deploy share
3. Back in production

## Ansible integration

Travel environment uses a separate inventory:

```
inventories/travel/
  hosts.yml          # travel nodes, ROSE, micro PC
  group_vars/
    all/main.yml     # deploy_share points to ROSE IP
    ...
```

Run with: `ansible-playbook playbooks/site.yml -i inventories/travel/ --limit <target>`

## Future considerations

- Travel PTP grandmaster: model TBD
- Container workloads on the ROSE (16-core ARM, 32GB RAM) if needed
