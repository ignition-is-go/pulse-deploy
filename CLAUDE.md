# CLAUDE.md

Production Ansible config for a multi-OS render farm (Proxmox). Windows UE/nDisplay render nodes, Linux CV VMs, Linux LXC containers.

## HARD RULES — READ BEFORE TOUCHING ANYTHING

1. **NEVER run a playbook without `--limit`**. There is no undo. If the user wants all hosts, they will say so explicitly.
2. **NEVER run `ansible-playbook` at all unless the user explicitly asks you to**. Writing/editing playbooks is fine. Executing them is not your call.
3. **NEVER put secrets in plaintext**. All secrets use `vault_` prefix vars in `inventories/*/group_vars/all/vault.yml`. Reference them from plain-text var files like `ansible_password: "{{ vault_ansible_password }}"`.
4. **NEVER create new files unless strictly necessary**. Edit existing files. Don't create helper scripts, wrapper playbooks, or utility roles for one-off tasks.
5. **NEVER add template files** (`roles/*/templates/`). This repo uses inline content via `win_copy content:` or `win_shell`. There are zero Jinja2 template files and that's intentional.
6. **NEVER use short module names**. Always use FQCN: `ansible.windows.win_shell`, `ansible.builtin.debug`, `community.windows.win_scheduled_task`, etc.
7. **NEVER use `ansible.builtin.*` modules on Windows hosts or `ansible.windows.*` modules on Linux hosts**. Check which group the play targets.
8. **NEVER modify `hosts.yml` group hierarchy without being asked**. The group tree (windows > ue > ue_content/ue_previs/ue_editing/ue_staging, linux > optik/rship/pulse_admin) is intentional.
9. **NEVER guess UE command-line flags or Ansible module parameters**. If you're not certain, say so. The user does not trust unverified engine suggestions.
10. **NEVER SSH, WinRM, or otherwise connect to remote hosts directly**. You are running on the Ansible control node. You cannot `ssh`, `Enter-PSSession`, `winrs`, or open any remote shell to managed nodes. All remote work goes through Ansible playbooks/ad-hoc commands — and even those require explicit user approval (rule 2).
11. **NEVER use Ansible tags to scope what a playbook runs**. Tags only filter when `--tags` is passed on the CLI — without it, everything runs. If a playbook should only run a subset of a role's tasks, use `include_role` with `tasks_from:` to include the specific task file. Never `{ role: foo, tags: [bar] }` as a way to limit what runs.
12. **NEVER delete or overwrite Plastic SCM config (`plastic4` directory) on nodes that have existing workspaces**. The config contains auth tokens and workspace registrations. Deleting it deregisters all workspaces and breaks auth. Only nuke config on fresh machines with zero registered workspaces.
13. **NEVER use defaults/overrides for variables**. Set values explicitly in each group_vars file where they are used. No "default in parent, override in child" patterns — it creates confusion and bugs. If `ue_content`, `ue_previs`, and `ue_staging` all need `plastic_workspace`, set it in each file independently.

## Architecture

**Layered roles, not node types.** A node's identity = which roles get applied.

```
Layer 0: OS base       → win_base, linux_base, lxc_base
Layer 1: Drivers       → nvidia_gpu_win, nvidia_gpu_linux, rivermax
Layer 2: Shared infra  → smb_share, linux_storage, plastic_scm
Layer 3: Applications  → unreal_engine, render_worker, arnold, optik, rship
```

**Role composition per node type:**

| Group | Roles |
|---|---|
| `ue_content` | win_base → nvidia_gpu_win → rivermax(cond) → plastic_scm → unreal_engine → render_worker |
| `ue_previs` | win_base → nvidia_gpu_win → rivermax(cond) → plastic_scm → unreal_engine → render_worker |
| `ue_editing` | win_base → nvidia_gpu_win → plastic_scm → unreal_engine |
| `ue_staging` | win_base → nvidia_gpu_win → plastic_scm → unreal_engine |
| `touch` | win_base → nvidia_gpu_win → rivermax(cond) |
| `optik` | linux_base → nvidia_gpu_linux → optik |
| `rship` | lxc_base → rship |

## Inventory Structure

```
all
├─ windows          (WinRM NTLM :5985)
│  ├─ ue
│  │  ├─ ue_content   (4 nDisplay render nodes, rivermax: true)
│  │  ├─ ue_previs    (1 previs editor, rivermax: true)
│  │  ├─ ue_editing   (1 multi-user Concert)
│  │  └─ ue_staging   (staging/build)
│  └─ touch           (1 touch display node, rivermax: true)
├─ linux            (SSH)
│  ├─ optik           (CV VM)
│  ├─ pulse_admin     (control node, local connection)
│  └─ rship           (3 LXC containers)
```

Multiple inventories: `hrlv-dev` (active), `hrlv-prod` (skeleton), `hrnyc` (skeleton), `example` (template).

## Variable Placement

Get this right or things break silently:

| Scope | Where | Examples |
|---|---|---|
| Secrets | `group_vars/all/vault.yml` (encrypted) | `vault_ansible_password`, `vault_plastic_api_key` |
| Global refs | `group_vars/all/main.yml` | `ansible_user: "{{ vault_ansible_user }}"` |
| All UE nodes | `group_vars/ue.yml` | `unreal_engine_dir`, `plastic_workspace`, `worker_path` |
| Per UE subgroup | `group_vars/ue_content.yml`, `ue_previs.yml`, etc. | `unreal_project` (different per group!), `ndisplay_map` |
| Per host | `hosts.yml` inline | `rivermax: true`, `media_ip`, `ndisplay_node`, `ndisplay_primary` |

**`unreal_project` is set per-group in `group_vars/ue_content.yml` / `ue_previs.yml` etc., NOT in `ue.yml`.** Each group points to a different `.uproject`.

**`rivermax` is a host-level boolean**, not a group. Applied conditionally with `when: rivermax | default(false)`.

## Windows / WinRM Constraints

This is the #1 source of bugs. Understand it before writing any Windows task.

**WinRM runs in Session 0** — an isolated service session, NOT the interactive desktop. Anything done via `win_shell` is invisible to the logged-in user:
- Mapped drives don't appear
- GPU/display access doesn't work
- Environment variables set with `[Environment]::SetEnvironmentVariable` won't apply until next logon
- Processes started via `win_shell` run headless in Session 0

**For anything the desktop user must see, use a scheduled task:**
```yaml
- name: Example — run in interactive session
  community.windows.win_scheduled_task:
    name: MyTask
    actions:
      - path: C:\my-script.bat
    username: "{{ ansible_user }}"
    password: "{{ ansible_password }}"
    logon_type: interactive_token
    run_level: highest
    state: present
```

The `render_worker`, `ue-ndisplay-start`, and Rivermax sender/receiver playbooks all use this pattern. Follow it.

**Plastic SCM (`cm.exe`) does NOT need scheduled tasks.** Cloud operations (workspace create, update, repository list) work fine via WinRM `win_shell`. The only requirement is working DNS — fresh VMs from cloudbase-init may not have DNS configured (see `win_base` role).

**Path quoting**: UE is installed at `F:/Epic Games/UE_5.7/` (note the space). The ndisplay launcher uses a `.bat` wrapper to handle this — do not try to pass spaced paths directly in scheduled task `arguments:`.

## Conventions

- **Idempotent tasks**: Check state before changing it. Use `win_stat`/`stat` to verify files exist, `changed_when: false` for read-only commands, `register` + conditional `when:` for skip logic.
- **Error handling**: Validate after changes (e.g., rivermax role checks DLL + license + adapter after install). Use `ansible.builtin.fail` with actionable error messages.
- **Preflight patterns**: `ue-ndisplay-start.yml` validates map exists on disk, runs Rivermax preflight checks, primes OVS FDB — all before launching. Follow this pattern for operational playbooks.
- **Async for long ops**: UE builds use `async: <seconds>` + `poll: 0` + `async_status` polling loop. See `build_pipeline` role.
- **No Jinja2 template files**: All dynamic content is built inline in playbooks via `win_copy content:` or `set_fact`. Don't add a `templates/` directory.
- **Playbook headers**: Include usage comments at top of playbooks (see `ue-ndisplay-start.yml` for example).
- **Serial control**: Use `serial: "{{ parallel_nodes | default(omit) }}"` when the user may want throttled rollouts.

## Key Files

| File | Purpose |
|---|---|
| `inventories/hrlv-dev/hosts.yml` | All hosts, groups, connection vars, host-level vars |
| `inventories/hrlv-dev/group_vars/all/vault.yml` | Encrypted secrets (vault) |
| `inventories/hrlv-dev/group_vars/ue.yml` | Shared UE config (engine path, Plastic, worker) |
| `inventories/hrlv-dev/group_vars/ue_content.yml` | nDisplay cluster config (project, map, configs) |
| `playbooks/site.yml` | Full convergence — applies all roles |
| `playbooks/ue-ndisplay-start.yml` | Launch nDisplay cluster (preflight → validate → launch) |
| `playbooks/deploy.yml` | Day-to-day Plastic sync + worker update |
| `ansible.cfg` | Default inventory, vault password file, collections paths |

## Commands

```bash
# ALWAYS use --limit unless explicitly targeting everything
ansible-playbook playbooks/site.yml --limit ue_content
ansible-playbook playbooks/site.yml --limit windows-unreal-render-01

# Day-to-day
ansible-playbook playbooks/deploy.yml --limit ue
ansible-playbook playbooks/ue-ndisplay-start.yml
ansible-playbook playbooks/ue-ndisplay-stop.yml

# Dry run (safe to run anytime)
ansible-playbook playbooks/site.yml --limit ue --check

# Status checks (read-only, safe)
ansible-playbook playbooks/status.yml
ansible-playbook playbooks/ptp-status.yml
ansible-playbook playbooks/plastic-status.yml
ansible all -m ping --limit windows

# Vault operations
ansible-vault edit inventories/hrlv-dev/group_vars/all/vault.yml
```

## Environment

- UE 5.7 at `F:/Epic Games/UE_5.7/`
- Windows Server 2025 Datacenter Evaluation (build 26100)
- Ansible control node is an LXC (locale: `en_US.UTF-8`)
- PTP grandmaster: Symmetricom at 10.0.0.100, domain 0, UDP E2E
- Mellanox ConnectX-6 VFs for Rivermax (no HW PTP clock — system clock fallback)
