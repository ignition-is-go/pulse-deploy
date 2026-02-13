# Auto-generated from Terraform outputs
# Copy relevant sections into inventory/hosts.yml

# --- UE Nodes ---
%{ for name, node in ue_nodes ~}
# ${name}:
#   ansible_host: ${node.ip}
#   rivermax: ${node.rivermax}
%{ endfor ~}

# --- Arnold Nodes ---
%{ for name, node in arnold_nodes ~}
# ${name}:
#   ansible_host: ${node.ip}
%{ endfor ~}

# --- Optik ---
%{ if optik_ip != null ~}
# optik-01:
#   ansible_host: ${optik_ip}
%{ endif ~}

# --- Control Plane ---
%{ if control_ip != null ~}
# ue-control-plane-01:
#   ansible_host: ${control_ip}
#   ansible_connection: local
%{ endif ~}

# --- rship Nodes ---
%{ for name, node in rship_nodes ~}
# ${name}:
#   ansible_host: ${node.ip}
%{ endfor ~}

# --- rship Control ---
%{ if rship_cp_ip != null ~}
# rship-cp-01:
#   ansible_host: ${rship_cp_ip}
%{ endif ~}
