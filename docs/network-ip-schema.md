# HRLV-DEV Network IP Schema

```
 192.168.1.1       Fortigate              gateway
 192.168.1.2       Cisco switch           1G mgmt switch
 192.168.1.3       TP-Link AP             WiFi AP
 192.168.1.4       BAP (Unifi)            WiFi AP
 192.168.1.5       Mellanox switch        100G media switch
 192.168.1.6       Symmetricom PTP        PTP GM mgmt (PTP: 10.0.0.100)
 192.168.1.7       Netgear switch         OOB mgmt switch
 192.168.1.8       UPS 1                  UPS (active)
 192.168.1.9       UPS 2                  UPS (broken)
 192.168.1.10      MikroTik ROSE          NAS/SMB
 192.168.1.11      MikroTik CRS518        25G/100G switch
 192.168.1.12-.19  —                      reserved
 192.168.1.21      micro-001              rship edge
 192.168.1.22      micro-002              rship edge
 192.168.1.23      micro-003              rship edge
 192.168.1.27-.29  —                      reserved
 192.168.1.31      nyc-pbs-01             PBS / NAS
 192.168.1.33-.39  —                      reserved
 192.168.1.42      nyc-dev-pve-02         proxmox
 192.168.1.43      nyc-dev-pve-03         proxmox
 192.168.1.46-.49  —                      reserved
 192.168.1.51      nyc-prod-pve-01        proxmox
 192.168.1.53-.59  —                      reserved
 192.168.1.61      nyc-prod-pve-02        proxmox
 192.168.1.63-.69  —                      reserved
 192.168.1.70      pulse-admin            LXC — Ansible control node
 192.168.1.71      bmc-pbs-01             BMC — nyc-pbs-01
 192.168.1.73      bmc-dev-pve-02         BMC — nyc-dev-pve-02
 192.168.1.74      bmc-dev-pve-03         BMC — nyc-dev-pve-03
 192.168.1.75      bmc-prod-pve-01        BMC — nyc-prod-pve-01
 192.168.1.76      bmc-prod-pve-02        BMC — nyc-prod-pve-02
 192.168.1.80-.99  —                      reserved
 
 DEV GUESTS — .100-.159 (VMID = 1000 + octet)
 CX6 VFs: 2110 = 10.0.0.{octet}, smb = 10.0.1.{octet}

 192.168.1.111      ue-staging-01          VM 1111, dev-pve-03
   10.0.0.111       2110
   10.0.1.111       smb
 192.168.1.112-.119  —                     reserved — staging
 192.168.1.126      workstation-01         VM 1126, dev-pve-02
   10.0.0.126       2110
   10.0.1.126       smb
 192.168.1.127      workstation-02         VM 1127, dev-pve-02
   10.0.0.127       2110
   10.0.1.127       smb
 192.168.1.128-.129  —                     reserved — workstation
 192.168.1.131      ue-plugindev-01        VM 1131, dev-pve-03
   10.0.0.131       2110
   10.0.1.131       smb
 192.168.1.132      ue-plugindev-02        VM 1132, dev-pve-03
   10.0.0.132       2110
   10.0.1.132       smb
 192.168.1.133-.139  —                     reserved — plugindev
 192.168.1.141      ue-runner-01           VM 1141, dev-pve-03
   10.0.0.141       2110
   10.0.1.141       smb
 192.168.1.142-.149  —                     reserved — runner
 192.168.1.151-.159  —                     reserved — arnold/fusion

 PROD GUESTS — .160-.199 (VMID = 1000 + octet)
 CX6 VFs: 2110 = 10.0.0.{octet}, smb = 10.0.1.{octet}

 192.168.1.161      ue-content-01          VM 1161, prod-pve-01, nDisplay
   10.0.0.161       2110
   10.0.1.161       smb
 192.168.1.162      ue-content-02          VM 1162, prod-pve-01, nDisplay   10.0.0.162       2110
   10.0.1.162       smb
 192.168.1.163      ue-content-03          VM 1163, prod-pve-01, nDisplay   10.0.0.163       2110
   10.0.1.163       smb
 192.168.1.164      ue-content-04          VM 1164, prod-pve-01, nDisplay   10.0.0.164       2110
   10.0.1.164       smb
 192.168.1.165      ue-content-05          VM 1165, prod-pve-01, nDisplay   10.0.0.165       2110
   10.0.1.165       smb
 192.168.1.166      ue-content-06          VM 1166, prod-pve-01, nDisplay   10.0.0.166       2110
   10.0.1.166       smb
 192.168.1.167      ue-content-07          VM 1167, prod-pve-01, nDisplay   10.0.0.167       2110
   10.0.1.167       smb
 192.168.1.168      ue-content-08          VM 1168, prod-pve-01, nDisplay   10.0.0.168       2110
   10.0.1.168       smb
 192.168.1.169      ue-content-09          VM 1169, prod-pve-02, nDisplay
   10.0.0.169       2110
   10.0.1.169       smb
 192.168.1.170      ue-content-10          VM 1170, prod-pve-02, nDisplay
   10.0.0.170       2110
   10.0.1.170       smb
 192.168.1.171      ue-content-11          VM 1171, prod-pve-02, nDisplay
   10.0.0.171       2110
   10.0.1.171       smb
 192.168.1.172      ue-content-12          VM 1172, prod-pve-02, nDisplay
   10.0.0.172       2110
   10.0.1.172       smb
 192.168.1.173      ue-content-13          VM 1173, prod-pve-02, nDisplay
   10.0.0.173       2110
   10.0.1.173       smb
 192.168.1.174      ue-content-14          VM 1174, prod-pve-02, nDisplay
   10.0.0.174       2110
   10.0.1.174       smb
 192.168.1.175      ue-content-15          VM 1175, prod-pve-02, nDisplay
   10.0.0.175       2110
   10.0.1.175       smb
 192.168.1.176      ue-content-16          VM 1176, prod-pve-02, nDisplay
   10.0.0.176       2110
   10.0.1.176       smb
 192.168.1.177      ue-editing-01          VM 1177, prod-pve-01
   10.0.0.177       2110
   10.0.1.177       smb
 192.168.1.178-.180  —                     reserved — editing
 192.168.1.181      ue-previs-01           VM 1181, prod-pve-01            10.0.0.181       2110
   10.0.1.181       smb
 192.168.1.182-.184  —                     reserved — previs
 192.168.1.185      touch-01               VM 1185, prod-pve-01
   10.0.0.185       2110
   10.0.1.185       smb
 192.168.1.186-.189  —                     reserved — touch
 192.168.1.191-.199  —                     reserved — optik

 192.168.1.200-.254                        DHCP

nyc-dev-pve-01 — travel unit (separate subnet)
 192.168.8.40      bmc-dev-pve-01         BMC
 192.168.8.41      nyc-dev-pve-01         proxmox
```