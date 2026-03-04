# HRLV-DEV Network & IP Schema

## Rack Topology

```
┌─────────────────────────────────────────────────────────────┐
│  Fortigate            192.168.1.1      gateway/router       │
├─────────────────────────────────────────────────────────────┤
│  Netgear switch       192.168.1.7      OOB management       │
├─────────────────────────────────────────────────────────────┤
│  Symmetricom PTP      192.168.1.6      mgmt                 │
│                       10.0.0.100       media (PTP GM)       │
├─────────────────────────────────────────────────────────────┤
│  Cisco switch         192.168.1.2      1G management        │
├─────────────────────────────────────────────────────────────┤
│  MikroTik ROSE        192.168.1.10     NAS/SMB              │
├─────────────────────────────────────────────────────────────┤
│  MikroTik CRS518      192.168.1.11     25G/100G switch      │
├─────────────────────────────────────────────────────────────┤
│  PoE injector                                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  nyc-pbs-01                            Proxmox Backup       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  nyc-dev-pve-01                       (travel — out of rack)│
├─────────────────────────────────────────────────────────────┤
│  nyc-dev-pve-02                                             │
├─────────────────────────────────────────────────────────────┤
│  nyc-dev-pve-03                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  Mellanox switch      192.168.1.5      100G media            │
├─────────────────────────────────────────────────────────────┤
│  nyc-prod-pve-01                                            │
├─────────────────────────────────────────────────────────────┤
│  nyc-prod-pve-02                                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  UPS 1                                 (active)             │
├─────────────────────────────────────────────────────────────┤
│  UPS 2                                 (broken — future)    │
└─────────────────────────────────────────────────────────────┘
```

## IP Allocation — 192.168.1.0/24

Three numbers to remember: **100, 160, 200.**

```
.1   - .99      PHYSICAL    everything with a chassis
.100 - .159     DEV         dev cluster guests (nyc-dev-pve-*)
.160 - .199     PROD        prod cluster guests (nyc-prod-pve-*)
.200 - .254     DHCP        temporary / unmanaged
```

nyc-dev-pve-01 is on a separate 192.168.8.x subnet (travel cluster) — not in this schema.

```
┌──────┬─────────────────────────┬──────────────┬──────────────────────────────────────────┐
│  IP  │  Name                   │  Type        │  Notes                                   │
├──────┼─────────────────────────┼──────────────┼──────────────────────────────────────────┤
│      │                         │              │                                          │
│      │  .1-.19 INFRASTRUCTURE   │              │                                          │
│      │                         │              │                                          │
│  .1  │  Fortigate              │  gateway     │  Router / firewall                       │
│  .2  │  Cisco switch           │  switch      │  1G management (trunked to Mellanox)     │
│  .3  │  TP-Link AP             │  wireless    │  WiFi access point                       │
│  .4  │  BAP (Unifi)            │  wireless    │  Basement access point                   │
│  .5  │  Mellanox switch        │  switch      │  100G media / ConnectX-6                 │
│  .6  │  Symmetricom PTP        │  clock       │  PTP GM mgmt interface                   │
│  .7  │  Netgear switch         │  switch      │  OOB management                          │
│  .8  │  UPS 1                  │  UPS         │  Active, web UI                          │
│  .9  │  UPS 2                  │  UPS         │  Broken — future repair                  │
│ .10  │  MikroTik ROSE          │  NAS         │  RouterOS SMB, expandable disk bays      │
│ .11  │  MikroTik CRS518       │  switch      │  CRS518-16XS-2XQ, 16x 25G + 2x 100G    │
│.12-19│  —                      │  reserved    │  Future infrastructure                   │
│      │                         │              │                                          │
│      │  .20-.29 RSHIP MICROS   │              │  Off-rack edge devices                   │
│      │                         │              │                                          │
│  .21 │  micro-001              │  micro PC    │  rship (existing)                        │
│  .22 │  micro-002              │  micro PC    │  rship (existing)                        │
│  .23 │  micro-003              │  micro PC    │  rship (existing)                        │
│  .24 │  kvm-micro-001          │  KVM-IP      │  If equipped                             │
│  .25 │  kvm-micro-002          │  KVM-IP      │  If equipped                             │
│  .26 │  kvm-micro-003          │  KVM-IP      │  If equipped                             │
│.27-29│  —                      │  reserved    │  Future edge devices                     │
│      │                         │              │                                          │
│      │  .30-.39 INFRA SERVERS  │              │  PBS, KVM                                │
│      │                         │              │                                          │
│  .31 │  nyc-pbs-01             │  PBS         │  Proxmox Backup Server (new install)     │
│  .32 │  kvm-pbs-01             │  KVM-IP      │  If equipped                             │
│.33-39│  —                      │  reserved    │                                          │
│      │                         │              │                                          │
│      │  .40-.49 DEV HYPERVISORS│              │                                          │
│      │                         │              │                                          │
│  .42 │  nyc-dev-pve-02         │  proxmox     │  9474F, 2x RTX 4090, 1x CX6 (new)        │
│  .43 │  nyc-dev-pve-03         │  proxmox     │  9474F, 2x RTX 4090, 1x CX6 (existing)   │
│  .44 │  kvm-dev-pve-02         │  KVM-IP      │  If equipped                             │
│  .45 │  kvm-dev-pve-03         │  KVM-IP      │  If equipped                             │
│.46-49│  —                      │  reserved    │  Future dev hypervisors                  │
│      │                         │              │                                          │
│      │  .50-.59 PROD-PVE-01    │              │                                          │
│      │                         │              │                                          │
│  .51 │  nyc-prod-pve-01        │  proxmox     │  2S 9575F, 8x RTX 6000 Ada, 2x CX6       │
│  .52 │  kvm-prod-pve-01        │  KVM-IP      │  If equipped                             │
│.53-59│  —                      │  reserved    │                                          │
│      │                         │              │                                          │
│      │  .60-.69 PROD-PVE-02    │              │                                          │
│      │                         │              │                                          │
│  .61 │  nyc-prod-pve-02        │  proxmox     │  2S 9575F, 8x RTX 6000 Ada, 2x CX6       │
│  .62 │  kvm-prod-pve-02        │  KVM-IP      │  If equipped                             │
│.63-69│  —                      │  reserved    │                                          │
│      │                         │              │                                          │
│      │  .70-.79 BMC / IPMI     │              │                                          │
│      │                         │              │                                          │
│      │                         │              │  NOTE: .71-.76 occupied by legacy render │
│      │                         │              │  nodes until ue-content migration done.  │
│      │                         │              │  Leave BMCs on DHCP until then.          │
│      │                         │              │                                          │
│  .71 │  bmc-pbs-01             │  BMC         │  IPMI for nyc-pbs-01                     │
│  .72 │  bmc-dev-pve-01         │  BMC         │  IPMI for nyc-dev-pve-01 (travel unit)   │
│  .73 │  bmc-dev-pve-02         │  BMC         │  IPMI for nyc-dev-pve-02                 │
│  .74 │  bmc-dev-pve-03         │  BMC         │  IPMI for nyc-dev-pve-03                 │
│  .75 │  bmc-prod-pve-01        │  BMC         │  IPMI for nyc-prod-pve-01                │
│  .76 │  bmc-prod-pve-02        │  BMC         │  IPMI for nyc-prod-pve-02                │
│.78-79│  —                      │  reserved    │                                          │
│      │                         │              │                                          │
│.80-99│  —                      │  reserved    │  Future physical expansion               │
│      │                         │              │                                          │
╞══════╪═════════════════════════╪══════════════╪══════════════════════════════════════════╡
│      │                         │              │                                          │
│      │  .100-.159 DEV GUESTS   │              │  VMs/LXCs on nyc-dev-pve-*               │
│      │                         │              │  VM ID = 1000 + last octet               │
│      │                         │              │                                          │
│ .100 │  —                      │  reserved    │  Range base                              │
│ .101 │  pulse-admin-dev        │  LXC (1101)  │  Control node clone (optional)           │
│.102-9│  —                      │  reserved    │  Dev Linux services                      │
│ .110 │  —                      │  reserved    │  Range base                              │
│ .111 │  ue-staging-01          │  VM (1111)   │  UE staging environment                  │
│ .112 │  ue-staging-02          │  VM (1112)   │  Backup staging                          │
│.113-9│  —                      │  reserved    │  Staging expansion                       │
│ .120 │  —                      │  reserved    │  Range base                              │
│ .121 │  ue-editing-01          │  VM (1121)   │  Concert multi-user server + editing     │
│.122-4│  —                      │  reserved    │  Editing expansion                       │
│ .125 │  —                      │  reserved    │  Range base                              │
│ .126 │  workstation-01         │  VM (1126)   │  Artist workstation (RDP)                │
│.127-9│  —                      │  reserved    │  Workstation expansion                   │
│ .130 │  —                      │  reserved    │  Range base                              │
│ .131 │  ue-plugindev-01        │  VM (1131)   │  UE plugin development                   │
│ .132 │  ue-plugindev-02        │  VM (1132)   │  UE plugin development                   │
│.133-9│  —                      │  reserved    │  Plugin dev expansion                    │
│ .140 │  —                      │  reserved    │  Range base                              │
│ .141 │  ue-runner-01           │  VM (1141)   │  UE CI/build runner                      │
│.142-9│  —                      │  reserved    │  Runner expansion                        │
│ .150 │  —                      │  reserved    │  Range base                              │
│ .151 │  arnold-01              │  VM (1151)   │  Arnold/Fusion offline render             │
│.152-9│  —                      │  reserved    │  Arnold/Fusion expansion                 │
│      │                         │              │                                          │
╞══════╪═════════════════════════╪══════════════╪══════════════════════════════════════════╡
│      │                         │              │                                          │
│      │  .160-.199 PROD GUESTS  │              │  VMs/LXCs on nyc-prod-pve-*              │
│      │                         │              │  VM ID = 1000 + last octet               │
│      │                         │              │                                          │
│ .160 │  pulse-admin            │  LXC (1160)  │  Ansible control node, Samba NAS         │
│ .161 │  ue-content-01          │  VM (1161)   │  nDisplay (primary)         media .161   │
│ .162 │  ue-content-02          │  VM (1162)   │  nDisplay                   media .162   │
│ .163 │  ue-content-03          │  VM (1163)   │  nDisplay                   media .163   │
│ .164 │  ue-content-04          │  VM (1164)   │  nDisplay                   media .164   │
│ .165 │  ue-content-05          │  VM (1165)   │                                          │
│ .166 │  ue-content-06          │  VM (1166)   │                                          │
│ .167 │  ue-content-07          │  VM (1167)   │                                          │
│ .168 │  ue-content-08          │  VM (1168)   │                                          │
│ .169 │  ue-content-09          │  VM (1169)   │                                          │
│ .170 │  ue-content-10          │  VM (1170)   │                                          │
│ .171 │  ue-content-11          │  VM (1171)   │                                          │
│ .172 │  ue-content-12          │  VM (1172)   │                                          │
│ .173 │  ue-content-13          │  VM (1173)   │                                          │
│ .174 │  ue-content-14          │  VM (1174)   │                                          │
│ .175 │  ue-content-15          │  VM (1175)   │                                          │
│ .176 │  ue-content-16          │  VM (1176)   │                                          │
│.177-9│  —                      │  reserved    │  Content cluster expansion               │
│ .180 │  —                      │  reserved    │  Range base                              │
│ .181 │  ue-previs-01           │  VM (1181)   │  Previs receiver            media .181   │
│.182-4│  —                      │  reserved    │  Previs expansion                        │
│ .185 │  touch-01               │  VM (1185)   │  TouchDesigner + Rivermax   media .185   │
│.186-9│  —                      │  reserved    │  Touch expansion                         │
│ .190 │  —                      │  reserved    │  Range base                              │
│ .191 │  optik-01               │  VM (1191)   │  CV / AI compute (GPU count varies)      │
│.192-9│  —                      │  reserved    │  Optik expansion                         │
│      │                         │              │                                          │
╞══════╪═════════════════════════╪══════════════╪══════════════════════════════════════════╡
│      │                         │              │                                          │
│      │  .200-.254 DHCP         │              │                                          │
│      │                         │              │                                          │
│.200- │  dynamic                │  DHCP pool   │  Laptops, phones, temp devices           │
│ .254 │                         │              │                                          │
└──────┴─────────────────────────┴──────────────┴──────────────────────────────────────────┘
```

## Media Network — 10.0.0.0/24 (Isolated)

No gateway, no DNS. SMPTE 2110 / Rivermax traffic only over ConnectX-6 SR-IOV VFs.
Last octet mirrors management IP for easy correlation.

```
┌──────────┬─────────────────────────┬──────────────────────────────────────────┐
│  IP      │  Name                   │  Notes                                   │
├──────────┼─────────────────────────┼──────────────────────────────────────────┤
│ .161     │  ue-content-01          │  nDisplay (primary)                      │
│ .162     │  ue-content-02          │  nDisplay                                │
│ .163     │  ue-content-03          │  nDisplay                                │
│ .164     │  ue-content-04          │  nDisplay                                │
│ .165-176 │  ue-content-05..16      │  nDisplay                                │
│ .181     │  ue-previs-01           │  Previs receiver                         │
│ .185     │  touch-01               │  TouchDesigner media I/O                 │
│ .250     │  Symmetricom PTP GM     │  Domain 0, UDP E2E (currently .100)      │
├──────────┼─────────────────────────┼──────────────────────────────────────────┤
│          │  MULTICAST 225.0.0.x    │                                          │
├──────────┼─────────────────────────┼──────────────────────────────────────────┤
│ 225.0.0. │                         │                                          │
│ .161-176 │  ue-content-01..16      │  Video out, port 50000                   │
└──────────┴─────────────────────────┴──────────────────────────────────────────┘
```

## Migration from Current State

```
┌───────────────────────────────┬────────────┬────────────┬────────────────────┐
│  Item                         │  Current   │  Target    │  Action            │
├───────────────────────────────┼────────────┼────────────┼────────────────────┤
│  KEEP — no change             │            │            │                    │
├───────────────────────────────┼────────────┼────────────┼────────────────────┤
│  Fortigate                    │  .1        │  .1        │  —                 │
│  Cisco switch                 │  .2        │  .2        │  —                 │
│  TP-Link AP                   │  .3        │  .3        │  —                 │
│  BAP (Unifi)                  │  .4        │  .4        │  —                 │
│  micro-001 (rship)            │  .21       │  .21       │  —                 │
│  micro-002 (rship)            │  .22       │  .22       │  —                 │
│  micro-003 (rship)            │  .23       │  .23       │  —                 │
│  nyc-dev-pve-03               │  .43       │  .43       │  —                 │
│  nyc-prod-pve-01              │  .51       │  .51       │  —                 │
│  nyc-prod-pve-02              │  .61       │  .61       │  —                 │
│  Mellanox switch              │  .5        │  .5        │  —                 │
│  Netgear switch               │  .7        │  .7        │  —                 │
│  Symmetricom PTP (mgmt)       │  .6        │  .6        │  —                 │
│  MikroTik ROSE (NAS)          │  .10       │  .10       │  —                 │
│  MikroTik CRS518 (switch)     │  .11       │  .11       │  —                 │
├───────────────────────────────┼────────────┼────────────┼────────────────────┤
│  MOVE — DHCP to static        │            │            │                    │
├───────────────────────────────┼────────────┼────────────┼────────────────────┤
│  All 6 server BMCs            │  DHCP      │  .71-.76   │  Set static        │
│  UPS 1                        │  DHCP      │  .8        │  Set static        │
│  UPS 2                        │  DHCP      │  .9        │  Set static        │
├───────────────────────────────┼────────────┼────────────┼────────────────────┤
│  NEW — fresh installs         │            │            │                    │
├───────────────────────────────┼────────────┼────────────┼────────────────────┤
│  nyc-dev-pve-02               │  —         │  .42       │  New OS install    │
│  nyc-pbs-01                   │  —         │  .31       │  New OS install    │
├───────────────────────────────┼────────────┼────────────┼────────────────────┤
│  MOVE — guest IPs (terraform) │            │            │                    │
├───────────────────────────────┼────────────┼────────────┼────────────────────┤
│  pulse-admin                  │  .70       │  .160      │  Move              │
│  ue-staging-01                │  .14       │  .111      │  Update terraform  │
│  touch-01                     │  .76       │  .185      │  Move + rename     │
│  ue-editing-01                │  .153      │  .121      │  Move + rename     │
│  ue-content-01..04 (mgmt)     │  .71-.74   │  .161-.164 │  Move + rename     │
│  ue-previs-01 (mgmt)          │  .75       │  .181      │  Move + rename     │
├───────────────────────────────┼────────────┼────────────┼────────────────────┤
│  MOVE — media network         │            │            │                    │
├───────────────────────────────┼────────────┼────────────┼────────────────────┤
│  ue-content-01..04 (media)    │ 10.0.0.1-4 │ 10.0.0.   │  Move               │
│                               │            │  161-164   │                    │
│  ue-previs-01 (media)         │ 10.0.0.5   │ 10.0.0.181│  Move               │
│  touch-01 (media)             │ 10.0.0.6   │ 10.0.0.185│  Move               │
│  PTP GM (media)               │ 10.0.0.100 │ 10.0.0.250│  Move (if feasible) │
└───────────────────────────────┴────────────┴────────────┴────────────────────┘
```
