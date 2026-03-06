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

## Future considerations

- Travel PTP grandmaster: model TBD
- Container workloads on the ROSE (16-core ARM, 32GB RAM) if needed
