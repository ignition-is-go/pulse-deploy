# CLAUDE.md

Production Ansible config for a multi-OS render farm (Proxmox). Windows UE/nDisplay render nodes, Linux CV VMs, Linux LXC containers.

> **YOU ARE RUNNING ON THE ANSIBLE CONTROL NODE (pulse-admin).** This is an LXC container that manages the entire render farm. `ansible_connection: local` means tasks targeting `pulse_admin` run as **root** directly on this machine. If you break this host, there is no recovery without Proxmox console access. `ansible_user` on this host resolves to `root` — NEVER pass it to user-management modules. Read every rule below before writing a single task.

## HARD RULES — READ BEFORE TOUCHING ANYTHING

1. **NEVER run a playbook without `--limit`**. There is no undo. If the user wants all hosts, they will say so explicitly.
2. **NEVER run `ansible-playbook` or ad-hoc `ansible` commands unless the user explicitly asks you to**. Writing/editing playbooks and roles is fine. Executing anything against remote hosts is not your call. This includes "just checking" or "verifying" via ad-hoc modules — if you need to verify something, put the verification task in the role/playbook itself so it runs as part of the normal workflow.
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
14. **NEVER use `win_shell` when a proper Ansible module exists**. `win_shell` is a last resort for when no module covers the operation. Prefer: `ansible.windows.win_package` over `Start-Process -FilePath ... -Wait` for installers, `ansible.windows.win_command` (with `argv:` list form for paths with spaces) over `& "path\to\exe" args` for running executables with no shell features needed, `ansible.windows.win_copy` / `ansible.windows.win_file` / `ansible.windows.win_stat` over PowerShell file ops. Only use `win_shell` when you genuinely need PowerShell features (pipes, cmdlets, variable expansion, error handling logic). Same applies to Linux: prefer `ansible.builtin.command` over `ansible.builtin.shell` unless shell features are required.
15. **NEVER hardcode external dynamic data in plays**. SSH host keys, certificates, API responses, version strings — anything sourced from an external service must be fetched at runtime (e.g., `ssh-keyscan` + `register`), never pasted as static strings. Static data rots silently when the source rotates keys or changes formats.
16. **NEVER use `ansible_user` as a general-purpose username variable**. `ansible_user` is the connection credential — on Windows hosts it's the vault-referenced admin account, but on `pulse_admin` (ansible_connection: local) it resolves to **root**. Using `ansible.builtin.user` with `name: "{{ ansible_user }}"` on the control node will modify the root account and can brick the machine. If a role needs a service account, SMB user, or application user, use a dedicated variable (`smb_user`, `samba_user`, etc.) — never derive it from `ansible_user`.
17. **NEVER modify system accounts (root, Administrator) with user-management modules**. Before using `ansible.builtin.user`, `ansible.windows.win_user`, or similar, verify the target name cannot resolve to a system account. Add a preflight check: `failed_when: resolved_user in ['root', 'Administrator', 'SYSTEM']`.

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
| `ue_content` | win_base → nvidia_gpu_win → rivermax(cond) → unreal_engine → render_worker |
| `ue_previs` | win_base → nvidia_gpu_win → rivermax(cond) → unreal_engine → render_worker |
| `ue_editing` | win_base → nvidia_gpu_win → unreal_engine |
| `ue_staging` | win_base → nvidia_gpu_win → plastic_scm → unreal_engine |
| `ue_plugin_dev` | win_base → nvidia_gpu_win → plastic_scm → git → vs_buildtools → unreal_engine |
| `win_ue_runner` | win_base → git → vs_buildtools → unreal_engine |
| `touch` | win_base → nvidia_gpu_win → rivermax(cond) |
| `pulse_admin` | linux_base → samba_server |
| `optik` | linux_base → nvidia_gpu_linux → optik |
| `rship` | lxc_base → rship |

## Inventory Structure

```
all
├─ windows          (WinRM NTLM :5985, become: runas for SMB access)
│  ├─ ue
│  │  ├─ ue_content   (4 nDisplay render nodes, rivermax: true)
│  │  ├─ ue_previs    (1 previs editor, rivermax: true)
│  │  ├─ ue_editing   (1 multi-user Concert)
│  │  └─ ue_staging   (staging/build)
│  └─ touch           (1 touch display node, rivermax: true)
├─ linux            (SSH)
│  ├─ optik           (CV VM)
│  ├─ pulse_admin     (control node, local connection — runs as root, ansible_user=root!)
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

**WinRM double-hop is solved via `become: runas`.** WinRM's NTLM transport creates a network logon (type 3) — credentials cannot be forwarded to a second network resource (e.g., SMB share on the NAS). All Windows hosts have `ansible_become: true` / `ansible_become_method: runas` in `hosts.yml`, which creates an interactive logon token (type 2) with full credential material. This means `win_stat`, `win_copy`, `win_command` etc. can access UNC paths (`\\192.168.1.70\deploy`) without any `net use` hacks. The `seclogon` (Secondary Logon) service must be running — `win_base` ensures this. **NEVER use `net use` with credentials in tasks to work around SMB access issues.** If UNC access fails, the problem is `become` configuration, not missing `net use`.

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

The `render_worker`, `ue-content-start`, and Rivermax sender/receiver playbooks all use this pattern. Follow it.

**Plastic SCM (`cm.exe`) does NOT need scheduled tasks.** Cloud operations (workspace create, update, repository list) work fine via WinRM `win_shell`. The only requirement is working DNS — fresh VMs from cloudbase-init may not have DNS configured (see `win_base` role).

**Path quoting**: Many paths have spaces (`F:/Epic Games/UE_5.7/`, `C:\Program Files\Git\...`). See the **YAML & Ansible Syntax** section for correct `argv` form. The ndisplay launcher uses a `.bat` wrapper because scheduled task `arguments:` can't handle spaced paths directly.

## Conventions

- **Idempotent tasks**: Check state before changing it. Use `win_stat`/`stat` to verify files exist, `changed_when: false` for read-only commands, `register` + conditional `when:` for skip logic.
- **Error handling**: Validate after changes (e.g., rivermax role checks DLL + license + adapter after install). Use `ansible.builtin.fail` with actionable error messages.
- **Preflight patterns**: `ue-content-start.yml` validates map exists on disk, runs Rivermax preflight checks, primes OVS FDB — all before launching. Follow this pattern for operational playbooks.
- **Async for long ops**: UE builds use `async: <seconds>` + `poll: 0` + `async_status` polling loop. See `build_pipeline` role.
- **No Jinja2 template files**: All dynamic content is built inline in playbooks via `win_copy content:` or `set_fact`. Don't add a `templates/` directory.
- **Playbook headers**: Include usage comments at top of playbooks (see `ue-content-start.yml` for example).
- **Serial control**: Use `serial: "{{ parallel_nodes | default(omit) }}"` when the user may want throttled rollouts.

## Ansible Task Guidelines

**Module selection — pick the most specific module for the job:**

| Operation | Use | NOT |
|---|---|---|
| Install MSI/EXE with product ID | `win_package` | `win_shell` + `Start-Process` / `msiexec` |
| Run an executable (no shell features) | `win_command` (with `argv:`) | `win_shell` + `& "path\to\exe"` |
| Copy a single file from NAS | `win_copy` + `remote_src: true` | `win_shell` + `Copy-Item` / `robocopy` |
| Copy a directory tree | `win_command` + `robocopy` | `win_shell` + robocopy (see Robocopy section) |
| Create a directory | `win_file` + `state: directory` | `win_shell` + `New-Item` |
| Check if a file/dir exists | `win_stat` + `register` | `win_shell` + `Test-Path` |
| Set a registry value | `win_regedit` | `win_shell` + `Set-ItemProperty` |
| Manage a Windows service | `win_service` | `win_shell` + `Set-Service` / `sc.exe` |
| Manage firewall rules | `community.windows.win_firewall_rule` | `win_shell` + `netsh` |
| Write inline content to a file | `win_copy` + `content:` | `win_shell` + echo/redirection |
| Query WMI / registry / complex PS | `win_shell` (legitimate use) | — |
| `Start-Process` for EXE installers | `win_shell` (no module for this) | — |

**The standard install pattern** — every role follows this structure:
```yaml
# 1. Check if already installed
- name: Check if X installed
  ansible.windows.win_stat:
    path: C:\path\to\evidence.exe
  register: x_check

# 2. Copy installer (conditional)
- name: Copy X from NAS
  ansible.windows.win_copy:
    src: "{{ x_installer_source }}"
    dest: C:\Windows\Temp\x-installer.exe
    remote_src: true
  when: not x_check.stat.exists

# 3. Install (conditional)
- name: Install X
  ansible.windows.win_package:            # or win_shell for EXE installers
    path: C:\Windows\Temp\x-installer.exe
    state: present
    product_id: X_product_id
  when: not x_check.stat.exists

# 4. Verify (unconditional — always runs)
- name: Verify X is callable
  ansible.windows.win_command:
    argv:
      - C:\path\to\evidence.exe
      - --version
  changed_when: false
```

Steps 1–3 are conditional (skip if installed). Step 4 always runs as a safety net. Never skip verification.

**Secrets**: Any task that handles secret values (`ansible_password`, deploy keys, API tokens) must have `no_log: true`. Reference secrets via vault indirection (`"{{ vault_xyz }}"` in `group_vars/all/main.yml`), never inline.

**Role headers**: Every role task file starts with a comment block naming the role, describing what it does, and listing required variables:
```yaml
---
# role_name — Short description of what this role does
#
# Requires (group_vars):
#   var_name: description of what this variable is
#   optional_var: (optional) description
```

**`win_shell` is only correct when you need PowerShell features:**
- Pipes: `Get-WmiObject ... | Where-Object { ... }`
- Cmdlets with no module equivalent: `Get-NetConnectionProfile`, `Get-ItemProperty`
- Complex control flow: `if/else`, `try/catch`, registry queries
- `Start-Process` for EXE installers that need `-ArgumentList` and `-Wait`
- Everything else has a dedicated module — use it

## YAML & Ansible Syntax

Follow these patterns exactly. Deviating from them is how bugs get introduced.

**`win_command` — always use `argv:` list form:**
```yaml
# CORRECT — argv handles spaces, no quoting needed
- ansible.windows.win_command:
    argv:
      - C:\Program Files\Git\cmd\git.exe
      - --version

# WRONG — free-form string breaks on spaces, nested quotes are fragile
- ansible.windows.win_command: '"C:\Program Files\Git\cmd\git.exe" --version'
```

**`win_shell` — `|` for multi-statement PowerShell, `>-` for single long commands:**
```yaml
# Literal block (|) — preserves newlines, use for PowerShell logic
- ansible.windows.win_shell: |
    $reg = Get-ItemProperty 'HKLM:\SOFTWARE\...\Uninstall\*' |
      Where-Object { $_.DisplayName -like '*WinOF*' }
    if ($reg) { $reg.DisplayVersion } else { "not_installed" }

# Folded block (>-) — joins lines into one command, use for long single commands
- ansible.windows.win_shell: >-
    Start-Process -FilePath "C:\Windows\Temp\installer.exe"
    -ArgumentList "/VERYSILENT /NORESTART"
    -Wait -PassThru
```

**YAML quoting rules:**
- `"{{ variable }}"` — double quotes when interpolating Jinja2 variables
- `bare_string` — no quotes for simple literal values (`state: present`, `name: MyTask`)
- `|` or `>-` — block scalars for anything multiline, never inline multiline strings

**`when:` conditionals:**
```yaml
# Bare for booleans and comparisons
when: not git_check.stat.exists
when: winof2_version.stdout | trim != rivermax_winof2_version

# Quoted for string containment tests
when: "'successfully authenticated' not in ssh_verify.stderr"
when: "'UnrealEditor.exe' in ue_running_check.stdout"

# List form for multiple conditions (implicit AND)
when:
  - rivermax_preflight is not skipped
  - "'FAIL' in rivermax_preflight.stdout"
```

**`changed_when` / `failed_when`:** Use `| trim` on stdout comparisons. Use `failed_when` with readable string checks, not exit code hacks:
```yaml
# CORRECT
failed_when: "'successfully authenticated' not in ssh_verify.stderr"

# WRONG — exit code gymnastics
ansible.windows.win_shell: >-
  & ssh -T git@github.com 2>&1;
  if ($LASTEXITCODE -eq 1) { exit 0 } else { exit $LASTEXITCODE }
```

**`win_copy content:` for generated files** (scripts, configs). `win_copy src: remote_src: true` for copying from NAS/network shares. Never build file content via `win_shell` echo/redirection.

## Robocopy in Ansible

Several roles use `robocopy` via `win_command` to copy large directory trees from the NAS (UE installer, VS Build Tools layout). Robocopy has non-standard exit codes that **will break Ansible** if not handled.

Reference: https://www.pdq.com/blog/hitchhikers-guide-to-robocopy/

**Exit codes 0–7 are success.** Only 8+ means failure. Robocopy returns non-zero on success (e.g., 1 = files copied, 3 = files copied + extras detected). Ansible sees non-zero and marks the task failed.

**Use async + poll: 0 + progress monitor for all robocopy tasks.** The monitor loop tails the log AND checks async completion in a single `until` task, so every 15s retry prints the last copied file (visible because `ansible.cfg` sets `verbosity = 1`):
```yaml
# 1. Fire robocopy in background
- name: Start copy from NAS
  ansible.windows.win_command: >-
    robocopy "{{ source }}" "{{ dest }}" /MIR /NDL /R:5 /W:10 /LOG:C:\Windows\Temp\robocopy-<name>.log
  async: 1800
  poll: 0
  register: copy_job
  when: not check.stat.exists

# 2. Tail log + check async status every 15s — stdout shows on each retry
- name: "Monitor copy progress"
  ansible.windows.win_shell: |
    $log = "C:\Windows\Temp\robocopy-<name>.log"
    if (Test-Path $log) { (Get-Content $log -Tail 1).Trim() } else { "waiting..." }
    $async = "$env:USERPROFILE\.ansible_async\{{ copy_job.ansible_job_id }}"
    if (Test-Path $async) {
      $status = Get-Content $async -Raw | ConvertFrom-Json
      if ($status.finished -eq 1) { exit 0 }
    }
    exit 1
  register: copy_progress
  until: copy_progress.rc == 0
  retries: 120
  delay: 15
  changed_when: false
  when: copy_job is not skipped

# 3. Collect real exit code for failed_when/changed_when
- name: Collect copy result
  ansible.builtin.async_status:
    jid: "{{ copy_job.ansible_job_id }}"
  register: copy_result
  failed_when: copy_result.rc >= 8
  changed_when: copy_result.rc in [1, 3, 5, 7]
  when: copy_job is not skipped
```

**Standard flags for NAS copies:**
- `/MIR` — mirror source to destination (copy + purge extras)
- `/NDL` — suppress directory listing (noise). Do NOT use `/NP` — the per-file progress percentage is what the monitor task tails
- `/R:5 /W:10` — **always include**. Default is 1M retries with 30s waits — robocopy will hang for days on a network blip without this
- `/LOG:C:\Windows\Temp\robocopy-<name>.log` — redirect output to log file. **Use `C:\Windows\Temp`**, not `C:\temp` (doesn't exist on fresh VMs)

**Do NOT use `Get-Process -Name Robocopy` to detect completion.** A stale robocopy from a previous failed run will match and the monitor will wait forever. Use `async_status` — it tracks the specific job ID.

**When to use robocopy vs `win_copy`:**
- `win_copy src: remote_src: true` — single files from NAS (`.exe`, `.msi`)
- `robocopy /MIR` — entire directory trees (UE installer with `Components/` subdirs, VS Build Tools offline layout)

**Robocopy does NOT need `win_shell`** — use `win_command` with `failed_when`/`changed_when` on `.rc`. No PowerShell features are needed.

## Key Files

| File | Purpose |
|---|---|
| `inventories/hrlv-dev/hosts.yml` | All hosts, groups, connection vars, host-level vars |
| `inventories/hrlv-dev/group_vars/all/vault.yml` | Encrypted secrets (vault) |
| `inventories/hrlv-dev/group_vars/ue.yml` | Shared UE config (engine path, Plastic, worker) |
| `inventories/hrlv-dev/group_vars/ue_content.yml` | nDisplay cluster config (project, map, configs) |
| `playbooks/apply-role.yml` | **Run a single role against a target — use this for iterative dev** |
| `playbooks/site.yml` | Full convergence — applies all roles |
| `playbooks/ue-content-start.yml` | Launch nDisplay cluster (preflight → validate → launch) |
| `playbooks/deploy.yml` | Day-to-day Plastic sync + worker update |
| `ansible.cfg` | Default inventory, vault password file, collections paths |

## Commands

```bash
# Single role against a target — USE THIS for iterative development
ansible-playbook playbooks/apply-role.yml -e target=ue-plugin-dev-01 -e role_name=git
ansible-playbook playbooks/apply-role.yml -e target=pulse_admin -e role_name=samba_server

# Full convergence — use --limit
ansible-playbook playbooks/site.yml --limit ue_content
ansible-playbook playbooks/site.yml --limit windows-unreal-render-01

# Day-to-day
ansible-playbook playbooks/deploy.yml --limit ue
ansible-playbook playbooks/ue-content-start.yml
ansible-playbook playbooks/ue-content-stop.yml

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
