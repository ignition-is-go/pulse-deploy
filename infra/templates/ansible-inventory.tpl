# Auto-generated from Terraform outputs — paste into inventories/hrlv/hosts.yml

# --- UE Render Nodes ---
%{ for name, node in ue_render_nodes ~}
# ${name}:
#   ansible_host: ${node.ip}
%{ endfor ~}

# --- Touch Nodes ---
%{ for name, node in touch_nodes ~}
# ${name}:
#   ansible_host: ${node.ip}
%{ endfor ~}

# --- Arnold Nodes ---
%{ for name, node in arnold_nodes ~}
# ${name}:
#   ansible_host: ${node.ip}
%{ endfor ~}

# --- Workstations ---
%{ for name, node in workstations ~}
# ${name}:
#   ansible_host: ${node.ip}
%{ endfor ~}

# --- Build Nodes ---
%{ for name, node in ue_build_nodes ~}
# ${name}:
#   ansible_host: ${node.ip}
%{ endfor ~}

# --- Staging Nodes ---
%{ for name, node in ue_staging_nodes ~}
# ${name}:
#   ansible_host: ${node.ip}
%{ endfor ~}

# --- Pixel Farm Nodes ---
%{ for name, node in pixelfarm_nodes ~}
# ${name}:
#   ansible_host: ${node.ip}
%{ endfor ~}

# --- Windows Runners ---
%{ for name, node in runner_win_nodes ~}
# ${name}:
#   ansible_host: ${node.ip}
%{ endfor ~}

# --- Optik Nodes ---
%{ for name, node in optik_nodes ~}
# ${name}:
#   ansible_host: ${node.ip}
%{ endfor ~}

# --- Linux Runners (LXC) ---
%{ for name, node in runner_lxc_nodes ~}
# ${name}:
#   ansible_host: ${node.ip}
%{ endfor ~}

# --- rship Nodes (LXC) ---
%{ for name, node in rship_nodes ~}
# ${name}:
#   ansible_host: ${node.ip}
%{ endfor ~}

# --- GitLab (LXC) ---
%{ for name, node in gitlab_nodes ~}
# ${name}:
#   ansible_host: ${node.ip}
%{ endfor ~}

# --- Pulse Admin (LXC) ---
%{ for name, node in pulse_admin_nodes ~}
# ${name}:
#   ansible_host: ${node.ip}
%{ endfor ~}
