# CLAUDE.md

Ansible config for a multi-OS render farm (Proxmox). Windows UE/nDisplay render nodes, Linux VMs, LXC containers.

> **YOU ARE ON THE ANSIBLE CONTROL NODE (pulse-admin).** LXC container, `ansible_connection: local`, runs as **root**. `ansible_user` resolves to `root` here — NEVER pass it to user-management modules. Breaking this host requires Proxmox console recovery.

## Rules

1. **NEVER run playbooks/ad-hoc commands unless user explicitly asks.** Always use `--limit`. Writing/editing playbooks is fine; executing is not your call.
2. **NEVER connect to remote hosts directly** (ssh, winrs, Enter-PSSession). All remote work goes through Ansible.
3. **Always use FQCN** (`ansible.windows.win_shell`, not `win_shell`). Never `ansible.builtin.*` on Windows or `ansible.windows.*` on Linux.
4. **Prefer proper modules over `win_shell`/`shell`.** `win_package` for installers, `win_command` (with `argv:` list) for executables, `win_copy`/`win_file`/`win_stat` for file ops. Only `win_shell` for PowerShell features (pipes, cmdlets, control flow).
5. **Secrets in vault only.** `vault_` prefix in `group_vars/all/vault.yml`. `no_log: true` on secret-handling tasks.
6. **No new files unless necessary.** No `templates/` directory. Inline content via `win_copy content:` or `set_fact`.
7. **No variable defaults/overrides.** Set values explicitly in each group_vars file independently.
8. **`ansible_user` is the connection credential, not a general username.** On pulse_admin it's root. Use dedicated vars (`smb_user`, etc.) for service accounts.
9. **Never modify system accounts** (root, Administrator) with user-management modules. Add preflight `failed_when` checks.
10. **Never use tags to scope playbooks.** Use `include_role` + `tasks_from:` instead.
11. **Never guess UE flags or module params.** Say you're unsure rather than guessing.
12. **Never delete Plastic SCM `plastic4` config** on nodes with existing workspaces — it deregisters all workspaces.
13. **Never hardcode external dynamic data.** Fetch at runtime (`ssh-keyscan` + `register`), never paste static strings.
14. **Never modify `hosts.yml` group hierarchy** without being asked.
15. **pulse-admin IS the Samba/NAS server.** The deploy share is locally mounted at `/mnt/deploy`. NEVER attempt to mount CIFS shares, use `net use`, or treat NAS paths as remote — just use `/mnt/deploy` directly. Installer convention: `/mnt/deploy/installers/<tool>/<version>/<filename>`.

## Architecture

Layered roles: OS base → Drivers → Shared infra → Applications. Node identity = which roles applied.

| Group | Roles |
|---|---|
| `ue_content`/`ue_previs` | win_base → nvidia_gpu_win → rivermax(cond) → unreal_engine → render_worker |
| `ue_editing` | win_base → nvidia_gpu_win → unreal_engine |
| `ue_staging` | win_base → nvidia_gpu_win → plastic_scm → unreal_engine |
| `ue_plugin_dev` | win_base → nvidia_gpu_win → plastic_scm → git → vs_buildtools → unreal_engine |
| `win_ue_runner` | win_base → git → vs_buildtools → unreal_engine |
| `pulse_admin` | linux_base → samba_server |
| `rship` | lxc_base → rship |

## Inventory

Two sources: `hosts.yml` (manual) + `terraform.yml` (Terraform state) — never duplicate hosts across them. Use `ansible-inventory --graph` to verify, NEVER pipe through python/jq.

```
windows (WinRM NTLM :5985, become: runas):
  ue:
    ue_content:     windows-unreal-render-01, -02, -03, -04
    ue_previs:      windows-unreal-render-05
    ue_editing:     windows-unreal-08
    ue_staging:     ue-staging-01          (terraform)
    ue_plugin_dev:  ue-plugindev-01, ue-plugindev-02
    win_ue_runner:  ue-runner-01
  touch:            windows-touch-01
linux (SSH):
  optik:            optik-01
  pulse_admin:      pulse-admin            (local, root!)
  rship:            rship-01, rship-02, rship-03
```

## Variables

| Scope | Where |
|---|---|
| Secrets | `group_vars/all/vault.yml` (encrypted) |
| Global refs | `group_vars/all/main.yml` |
| All UE nodes | `group_vars/ue.yml` |
| Per subgroup | `group_vars/ue_content.yml`, `ue_previs.yml`, etc. |
| Per host | `hosts.yml` inline (`rivermax`, `media_ip`, `ndisplay_node`) |

`unreal_project` is per-group (NOT `ue.yml`). `rivermax` is a host-level boolean.

## WinRM Constraints

- **Double-hop solved via `become: runas`** — interactive logon (type 2) for SMB access. Never use `net use` workarounds.
- **Session 0**: WinRM tasks invisible to desktop user. Use `community.windows.win_scheduled_task` with `logon_type: interactive_token` for interactive tasks.
- **Paths with spaces**: Always use `win_command` `argv:` list form. Scheduled tasks use `.bat` wrappers.
- **Plastic SCM** cloud ops work fine via WinRM (no scheduled task needed).

## Patterns

- **Install**: win_stat check → conditional copy → conditional install → unconditional verify
- **Robocopy**: `win_command` (not `win_shell`), `async` + progress monitor, `failed_when: rc >= 8`, always `/R:5 /W:10`
- **Idempotent**: Check state before changing. `register` + `when:` for skip logic. `changed_when: false` for read-only.
- **Role headers**: Comment block with role name, description, required variables
- **Async**: Long ops use `async:` + `poll: 0` + `async_status` polling loop

## Key Files

| File | Purpose |
|---|---|
| `playbooks/apply-role.yml` | Run a single role against a target — use for iterative dev |
| `playbooks/site.yml` | Full convergence — applies all roles |
| `playbooks/ue-content-start.yml` | Launch nDisplay cluster (preflight → validate → launch) |
| `playbooks/deploy.yml` | Day-to-day Plastic sync + worker update |
| `inventories/hrlv-dev/hosts.yml` | All hosts, groups, connection vars |
| `inventories/hrlv-dev/group_vars/` | Variable files (all/, ue.yml, ue_content.yml, etc.) |

## Commands

```bash
ansible-playbook playbooks/apply-role.yml -e target=HOST -e role_name=ROLE  # iterative dev
ansible-playbook playbooks/site.yml --limit GROUP                           # convergence
ansible-playbook playbooks/deploy.yml --limit ue                            # day-to-day
ansible-playbook playbooks/ue-content-start.yml                             # launch nDisplay
ansible-playbook playbooks/site.yml --limit ue --check                      # dry run
ansible windows -m ansible.windows.win_ping                                 # connectivity check
ansible-vault edit inventories/hrlv-dev/group_vars/all/vault.yml            # edit secrets
```

## Environment

- UE 5.7 at `F:/Epic Games/UE_5.7/`
- Windows Server 2025 Datacenter Evaluation (build 26100)
- Control node: LXC, locale `en_US.UTF-8`
- PTP: Symmetricom at 10.0.0.100, domain 0, UDP E2E
- Mellanox ConnectX-6 VFs for Rivermax (system clock fallback)
