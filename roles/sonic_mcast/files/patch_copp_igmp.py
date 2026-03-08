#!/usr/bin/env python3
"""Idempotently patch /etc/sonic/copp_cfg.json to add IGMP CoPP trap.

Adds queue4_group4 (dedicated IGMP trap group) and an igmp COPP_TRAP
entry with always_enabled=true. Leaves all other entries untouched.

Prints CHANGED if the file was modified, OK if already correct.
"""

import json
import sys

COPP_FILE = "/etc/sonic/copp_cfg.json"

IGMP_GROUP = {
    "trap_action": "trap",
    "trap_priority": "4",
    "queue": "4",
    "meter_type": "packets",
    "mode": "sr_tcm",
    "cir": "6000",
    "cbs": "6000",
    "red_action": "drop",
}

IGMP_TRAP = {
    "trap_ids": "igmp_query,igmp_leave,igmp_v1_report,igmp_v2_report,igmp_v3_report",
    "trap_group": "queue4_group4",
    "always_enabled": "true",
}

try:
    with open(COPP_FILE) as f:
        cfg = json.load(f)
except (FileNotFoundError, json.JSONDecodeError) as e:
    print(f"ERROR: cannot read {COPP_FILE}: {e}", file=sys.stderr)
    sys.exit(1)

changed = False

# Ensure COPP_GROUP and COPP_TRAP sections exist
cfg.setdefault("COPP_GROUP", {})
cfg.setdefault("COPP_TRAP", {})

# Add or update queue4_group4
if cfg["COPP_GROUP"].get("queue4_group4") != IGMP_GROUP:
    cfg["COPP_GROUP"]["queue4_group4"] = IGMP_GROUP
    changed = True

# Add or update igmp trap entry
if cfg["COPP_TRAP"].get("igmp") != IGMP_TRAP:
    cfg["COPP_TRAP"]["igmp"] = IGMP_TRAP
    changed = True

if changed:
    with open(COPP_FILE, "w") as f:
        json.dump(cfg, f, indent=4)
        f.write("\n")
    print("CHANGED")
else:
    print("OK")
