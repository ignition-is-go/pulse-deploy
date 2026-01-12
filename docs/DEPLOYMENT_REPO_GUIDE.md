# Production Deployment Repository Guide

A comprehensive guide for structuring and maintaining deployment repositories, designed for both human developers and AI agents.

---

## Quick Start

Get a working deployment in 5 minutes:

```bash
# 1. Clone the repository
git clone https://github.com/your-org/pulse-deploy.git
cd pulse-deploy

# 2. Preview what will be configured (safe, no changes made)
DRY_RUN=1 ./setup.sh

# 3. Run the actual deployment (requires root)
sudo ./setup.sh

# 4. Verify the deployment
./tests/validate-all.sh
```

### Minimal setup.sh Example

```bash
#!/bin/bash
# setup.sh - Main orchestrator for deployment
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="$SCRIPT_DIR"

source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/validation.sh"

# Module execution order (respects dependencies)
readonly MODULES=(
    "kernel"      # Kernel params - no dependencies
    "hugepages"   # Memory config - no dependencies
    "network"     # Network config - after kernel
    "ptp"         # Time sync - after network
    "rdma"        # RDMA setup - after network, hugepages
    "evt"         # EVT cameras - after all above
)

main() {
    info "=== Pulse Deployment ==="

    # Load configuration
    load_config "${ENVIRONMENT:-production}"

    # Pre-flight checks
    preflight_check || fatal "Pre-flight checks failed"

    # Run each module
    local failed=0
    for module in "${MODULES[@]}"; do
        info "--- Running module: $module ---"
        if ! "$REPO_ROOT/modules/$module/install.sh"; then
            err "Module $module failed"
            ((failed++))
            [[ "${FAIL_FAST:-true}" == "true" ]] && break
        fi
    done

    if [[ $failed -eq 0 ]]; then
        info "=== Deployment Complete ==="
    else
        fatal "Deployment failed: $failed module(s) had errors"
    fi
}

main "$@"
```

### What Success Looks Like

```
[2024-12-15 10:30:00] [INFO] === Pulse Deployment ===
[2024-12-15 10:30:00] [INFO] Loading production.conf
[2024-12-15 10:30:00] [INFO] Running pre-flight checks...
[2024-12-15 10:30:01] [INFO] Pre-flight checks passed
[2024-12-15 10:30:01] [INFO] --- Running module: kernel ---
[2024-12-15 10:30:02] [INFO] [kernel] Already configured
[2024-12-15 10:30:02] [INFO] --- Running module: hugepages ---
[2024-12-15 10:30:03] [INFO] [hugepages] Allocated 1024 huge pages
[2024-12-15 10:30:03] [INFO] --- Running module: network ---
[2024-12-15 10:30:05] [INFO] [network] Configured enp2s0f0np0 with 10.0.0.1/24
[2024-12-15 10:30:05] [INFO] --- Running module: ptp ---
[2024-12-15 10:30:07] [INFO] [ptp] Service started, syncing to grandmaster
[2024-12-15 10:30:07] [INFO] --- Running module: rdma ---
[2024-12-15 10:30:08] [INFO] [rdma] RDMA configured for Rivermax
[2024-12-15 10:30:08] [INFO] --- Running module: evt ---
[2024-12-15 10:30:09] [INFO] [evt] Camera routes configured
[2024-12-15 10:30:09] [INFO] === Deployment Complete ===
```

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Repository Philosophy](#repository-philosophy)
3. [Directory Structure](#directory-structure)
4. [Module Design](#module-design)
5. [Script Conventions](#script-conventions)
6. [Configuration Management](#configuration-management)
7. [Secrets Management](#secrets-management)
8. [Security Hardening](#security-hardening)
9. [Hardware Detection](#hardware-detection)
10. [RDMA and Rivermax Configuration](#rdma-and-rivermax-configuration)
11. [Testing and Validation](#testing-and-validation)
12. [Backup and Recovery](#backup-and-recovery)
13. [Troubleshooting](#troubleshooting)
14. [Agent Instructions](#agent-instructions)
15. [References](#references)

---

## Repository Philosophy

### Core Principles

1. **Separation of Concerns**: Divide by rate of change and responsibility
   - **Static configs**: Rarely change (sysctl, kernel params, BIOS settings)
   - **Network configs**: Change per-environment
   - **Service configs**: Change with application updates
   - **Scripts**: Change with deployment logic

2. **Idempotency**: Every script must be safe to run multiple times
   - Check state before modifying
   - Skip if already configured (exit code 2)
   - Report current state on no-op

3. **Fail-Fast**: Detect problems early
   - Validate inputs before making changes
   - Check prerequisites at script start
   - Use `set -euo pipefail` in all scripts

4. **Composability**: Small, focused scripts that can be combined
   - Each script does one thing well
   - Scripts can be run independently or orchestrated
   - Shared functions in libraries

5. **12-Factor Configuration**: Config strictly separated from code
   - Environment variables as the single source of truth
   - Never hardcode credentials or environment-specific values
   - Litmus test: "Could this codebase be open-sourced without compromising credentials?"

### What Counts as "Environment-Specific"

| Environment-Specific (use config) | Safe to Hardcode |
|-----------------------------------|------------------|
| IP addresses, subnets | File paths within repo (`$REPO_ROOT/...`) |
| Hostnames, domain names | Default port numbers (well-known ports) |
| Credentials, API keys | Package names |
| Interface names (can vary) | Sysctl parameter names |
| PTP domain numbers | Service unit names |
| Resource limits (hugepages count) | Log format strings |

---

## Directory Structure

### Recommended Layout

```
deployment-repo/
├── README.md                    # Quick start and overview
├── setup.sh                     # Main entry point (orchestrator)
├── Makefile                     # Alternative entry point
│
├── docs/                        # Documentation
│   ├── DEPLOYMENT_REPO_GUIDE.md # This guide
│   ├── TROUBLESHOOTING.md       # Common issues and solutions
│   └── COMPLIANCE.md            # CIS/SOC2 mapping (optional)
│
├── lib/                         # Shared shell libraries (source, never execute)
│   ├── common.sh                # Logging, error handling, utilities
│   ├── detect.sh                # Hardware/interface detection
│   ├── assert.sh                # Assertion helpers for validation
│   ├── validation.sh            # Input/state validation
│   ├── security.sh              # Security helpers (permissions, secrets)
│   ├── backup.sh                # Backup and restore utilities
│   └── rdma.sh                  # RDMA-specific helpers
│
├── modules/                     # Deployment modules (one per subsystem)
│   ├── kernel/                  # Kernel parameters
│   ├── hugepages/               # Memory configuration
│   ├── network/                 # Network configuration
│   ├── ptp/                     # PTP time sync
│   ├── rdma/                    # RDMA/Rivermax setup
│   └── evt/                     # EVT camera support
│
├── config/                      # Environment-specific configuration
│   ├── defaults.conf            # Default values (always loaded first)
│   ├── production.conf          # Production overrides
│   ├── staging.conf             # Staging overrides
│   └── local.conf.example       # Template for local overrides
│
├── hardware/                    # Hardware-specific profiles
│   ├── profiles/
│   │   ├── cx6-pf.conf          # ConnectX-6 Physical Function
│   │   ├── cx6-vf.conf          # ConnectX-6 Virtual Function
│   │   └── generic.conf         # Fallback
│   └── detect-profile.sh
│
├── hooks/                       # Deployment lifecycle hooks
│   ├── pre-deploy.sh
│   ├── post-deploy.sh
│   └── rollback.sh
│
└── tests/                       # Validation scripts
    ├── test_*.bats              # Bats test files
    ├── test_helpers.bash
    └── validate-all.sh
```

### Module Structure

Each module follows this structure:

```
modules/<name>/
├── README.md           # What, why, how, troubleshooting
├── metadata.sh         # Version, dependencies, conflicts
├── install.sh          # Main entry point - idempotent
├── uninstall.sh        # Clean removal (optional)
├── status.sh           # Check current state (optional)
├── templates/          # Config templates (.tmpl)
└── files/              # Static files
```

---

## Module Design

### Module Metadata

Every module should have a `metadata.sh` file:

```bash
#!/bin/bash
# modules/network/metadata.sh

readonly MODULE_NAME="network"
readonly MODULE_VERSION="1.0.0"
readonly MODULE_DESCRIPTION="Configure NetworkManager for EVT camera network"

# Dependencies - modules that must run before this one
readonly MODULE_DEPENDS=("kernel")

# Conflicts - modules that cannot coexist
readonly MODULE_CONFLICTS=()

# Required commands
readonly MODULE_REQUIRES_COMMANDS=(nmcli ip ethtool)

# Files this module modifies (for backup)
readonly MODULE_MODIFIES=(
    "/etc/NetworkManager/system-connections/evt-cameras.nmconnection"
)
```

### Module Contract

Every `install.sh` must:

1. **Source common library first**: `source "$REPO_ROOT/lib/common.sh"`
2. **Be idempotent**: Safe to run multiple times
3. **Exit with proper codes**:
   - `0` = success (changes made)
   - `1` = error
   - `2` = no-op (already configured)
4. **Log all actions**: Use `info`, `warn`, `err` from common.sh
5. **Support dry-run**: Respect `DRY_RUN=1`
6. **Validate before modifying**: Check prerequisites first
7. **Backup before changing**: Use backup helpers for modified files
8. **Use local variables**: All function variables must be `local`
9. **Use readonly for constants**: `readonly MODULE_NAME="..."`

### Example Module Script

```bash
#!/bin/bash
# modules/hugepages/install.sh
#
# Configures huge pages for RDMA/Rivermax DMA buffers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source shared libraries
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/assert.sh"
source "$REPO_ROOT/lib/backup.sh"

# Module constants
readonly MODULE_NAME="hugepages"
readonly SYSCTL_FILE="/etc/sysctl.d/99-hugepages.conf"
readonly SOURCE_FILE="$SCRIPT_DIR/files/99-hugepages.conf"

#######################################
# Check prerequisites before any changes
#######################################
check_prerequisites() {
    assert_root
    assert_file_exists "$SOURCE_FILE"
    assert_command sysctl
}

#######################################
# Check if module is already configured
# Returns: 0 if configured correctly, 1 if not
#######################################
is_configured() {
    [[ -f "$SYSCTL_FILE" ]] || return 1
    diff -q "$SOURCE_FILE" "$SYSCTL_FILE" &>/dev/null
}

#######################################
# Install hugepages configuration
#######################################
install() {
    # Check prerequisites BEFORE making any changes
    check_prerequisites

    # Check if already configured
    if is_configured; then
        info "[$MODULE_NAME] Already configured"
        return 2
    fi

    # Backup existing file if present
    backup_file "$SYSCTL_FILE"

    # Install new configuration
    info "[$MODULE_NAME] Installing sysctl config"
    run_cmd cp "$SOURCE_FILE" "$SYSCTL_FILE"
    run_cmd chmod 644 "$SYSCTL_FILE"
    run_cmd sysctl -p "$SYSCTL_FILE"

    # Verify
    local pages
    pages=$(awk '/HugePages_Total/ {print $2}' /proc/meminfo)
    if [[ "$pages" -lt "${HUGEPAGES_COUNT:-512}" ]]; then
        warn "[$MODULE_NAME] Only $pages hugepages allocated (wanted ${HUGEPAGES_COUNT:-512})"
        warn "[$MODULE_NAME] May need reboot for full allocation"
    else
        info "[$MODULE_NAME] Allocated $pages huge pages"
    fi

    return 0
}

#######################################
# Main
#######################################
main() {
    info "[$MODULE_NAME] Starting installation"
    install
    local exit_code=$?

    case $exit_code in
        0) info "[$MODULE_NAME] Installation complete" ;;
        2) info "[$MODULE_NAME] No changes needed" ;;
        *) err "[$MODULE_NAME] Installation failed" ;;
    esac

    return $exit_code
}

main "$@"
```

---

## Script Conventions

### Library: lib/common.sh

```bash
#!/bin/bash
# lib/common.sh - Shared functions for all scripts
#
# USAGE: source "$REPO_ROOT/lib/common.sh"
#
# This file should NEVER be executed directly.
# Libraries are sourced, not run.

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: This script should be sourced, not executed" >&2
    exit 1
fi

# Strict mode
set -euo pipefail

# Determine library directory
readonly LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors (disabled if not a terminal or if NO_COLOR is set)
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[0;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

#######################################
# Logging functions
# All log to stderr to keep stdout clean for data
#######################################
_log() {
    local level="$1"
    local color="$2"
    shift 2
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${color}[${timestamp}] [${level}]${NC} $*" >&2
}

info()  { _log "INFO" "$GREEN" "$@"; }
warn()  { _log "WARN" "$YELLOW" "$@"; }
err()   { _log "ERROR" "$RED" "$@"; }
debug() { [[ "${DEBUG:-0}" == "1" ]] && _log "DEBUG" "$BLUE" "$@" || true; }

fatal() {
    err "$@"
    exit 1
}

#######################################
# Run command with DRY_RUN support
# SECURITY: Does not log command if it might contain secrets
# Arguments:
#   Command and arguments to run
#######################################
run_cmd() {
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        # In dry-run, show command (but mask if potentially sensitive)
        if [[ "$*" =~ (password|secret|key|token) ]]; then
            info "[DRY-RUN] <command with sensitive data>"
        else
            info "[DRY-RUN] $*"
        fi
        return 0
    fi

    # Disable xtrace temporarily to avoid logging secrets
    local old_opts="$-"
    set +x

    debug "Executing: $*"
    "$@"
    local exit_code=$?

    # Restore xtrace if it was enabled
    [[ "$old_opts" == *x* ]] && set -x

    return $exit_code
}

#######################################
# Require root privileges
# NOTE: Does NOT use exec - safe for sourced scripts
#######################################
require_root() {
    if [[ $EUID -ne 0 ]]; then
        if [[ -n "${SUDO_USER:-}" ]]; then
            # Already running under sudo
            return 0
        fi
        fatal "This script requires root privileges. Run with: sudo $0"
    fi
}

#######################################
# Load configuration files in order
# Priority: defaults < environment < local < env vars
# Globals:
#   REPO_ROOT - must be set before calling
# Arguments:
#   env: Environment name (optional)
#######################################
load_config() {
    local env="${1:-${ENVIRONMENT:-defaults}}"
    local config_dir="${REPO_ROOT}/config"

    # Load defaults first (lowest priority)
    if [[ -f "$config_dir/defaults.conf" ]]; then
        debug "Loading defaults.conf"
        # shellcheck source=/dev/null
        source "$config_dir/defaults.conf"
    fi

    # Load environment-specific config
    if [[ "$env" != "defaults" && -f "$config_dir/${env}.conf" ]]; then
        debug "Loading ${env}.conf"
        # shellcheck source=/dev/null
        source "$config_dir/${env}.conf"
    fi

    # Load local overrides (highest file priority, gitignored)
    if [[ -f "$config_dir/local.conf" ]]; then
        debug "Loading local.conf"
        # shellcheck source=/dev/null
        source "$config_dir/local.conf"
    fi

    # Environment variables override everything (handled automatically)
    info "Configuration loaded for environment: $env"
}

#######################################
# Process a template file with variable substitution
# SECURITY: Only substitutes explicitly listed variables
# Arguments:
#   template_file: Path to template
#   output_file: Path to write output
#   variables: Space-separated list of variable names to substitute
#######################################
process_template() {
    local template="$1"
    local output="$2"
    local variables="${3:-}"

    if [[ ! -f "$template" ]]; then
        fatal "Template not found: $template"
    fi

    if [[ -z "$variables" ]]; then
        # Default safe variables for this project
        variables='$PTP_DOMAIN $PTP_INTERFACE $PTP_TRANSPORT $CX6_MTU $EVT_CAMERA_SUBNET $EVT_HOST_IP $HUGEPAGES_COUNT'
    fi

    debug "Processing template: $template -> $output"
    debug "Substituting variables: $variables"

    # Use explicit variable list to prevent secret leakage
    envsubst "$variables" < "$template" > "$output"

    # Verify output was created and is not empty
    if [[ ! -s "$output" ]]; then
        fatal "Template processing failed: output is empty"
    fi
}

#######################################
# Cleanup handler with signal support
# Usage: trap 'cleanup "$LINENO"' EXIT ERR INT TERM
#######################################
cleanup() {
    local exit_code=$?
    local line_no="${1:-unknown}"

    # Kill any background jobs we started
    local jobs_list
    jobs_list=$(jobs -p 2>/dev/null) || true
    if [[ -n "$jobs_list" ]]; then
        debug "Terminating background jobs"
        kill $jobs_list 2>/dev/null || true
        wait $jobs_list 2>/dev/null || true
    fi

    # Remove temporary files
    if [[ -n "${TMP_FILE:-}" && -f "$TMP_FILE" ]]; then
        rm -f "$TMP_FILE"
    fi
    if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi

    # Log failure location
    if [[ $exit_code -ne 0 && $exit_code -ne 2 ]]; then
        err "Script failed at line $line_no (exit code: $exit_code)"
    fi

    exit "$exit_code"
}
```

### Library: lib/assert.sh

```bash
#!/bin/bash
# lib/assert.sh - Assertion helpers for fail-fast validation

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: This script should be sourced, not executed" >&2
    exit 1
fi

#######################################
# Assert a value is non-empty
#######################################
assert_non_empty() {
    local value="$1"
    local message="${2:-Value cannot be empty}"
    if [[ -z "$value" ]]; then
        fatal "$message"
    fi
}

#######################################
# Assert a file exists and is readable
#######################################
assert_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        fatal "File does not exist: $file"
    fi
    if [[ ! -r "$file" ]]; then
        fatal "File is not readable: $file"
    fi
}

#######################################
# Assert a directory exists
#######################################
assert_dir_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        fatal "Directory does not exist: $dir"
    fi
}

#######################################
# Assert a command is available
#######################################
assert_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        fatal "Required command not found: $cmd"
    fi
}

#######################################
# Assert running as root
#######################################
assert_root() {
    if [[ $EUID -ne 0 ]]; then
        fatal "This operation requires root privileges"
    fi
}

#######################################
# Assert a network interface exists
#######################################
assert_interface_exists() {
    local iface="$1"
    if [[ ! -d "/sys/class/net/$iface" ]]; then
        fatal "Network interface does not exist: $iface"
    fi
}

#######################################
# Assert valid interface name (security: prevent path traversal)
#######################################
assert_valid_interface_name() {
    local iface="$1"
    # Only allow alphanumeric, dots, underscores, hyphens
    if [[ ! "$iface" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        fatal "Invalid interface name (possible injection): $iface"
    fi
}

#######################################
# Assert valid IPv4 address
#######################################
assert_valid_ipv4() {
    local ip="$1"
    local pattern='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

    if [[ ! "$ip" =~ $pattern ]]; then
        fatal "Invalid IPv4 address: $ip"
    fi

    # Validate octets are 0-255
    local IFS='.'
    local -a octets=($ip)
    for octet in "${octets[@]}"; do
        if ((octet > 255)); then
            fatal "Invalid IPv4 address (octet > 255): $ip"
        fi
    done
}

#######################################
# Assert valid CIDR notation
#######################################
assert_valid_cidr() {
    local cidr="$1"

    if [[ ! "$cidr" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        fatal "Invalid CIDR notation: $cidr"
    fi

    local ip="${cidr%/*}"
    local prefix="${cidr##*/}"

    assert_valid_ipv4 "$ip"

    if [[ "$prefix" -lt 0 || "$prefix" -gt 32 ]]; then
        fatal "Invalid CIDR prefix (must be 0-32): $prefix"
    fi
}
```

### Library: lib/backup.sh

```bash
#!/bin/bash
# lib/backup.sh - Backup and restore utilities

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: This script should be sourced, not executed" >&2
    exit 1
fi

readonly BACKUP_DIR="${BACKUP_DIR:-/var/backups/pulse-deploy}"

#######################################
# Backup a file before modification
# Arguments:
#   file: File to backup
# Returns:
#   0 on success, 1 if file doesn't exist (OK to proceed)
#######################################
backup_file() {
    local file="$1"

    # Nothing to backup if file doesn't exist
    [[ -f "$file" ]] || return 0

    # Create backup directory
    if [[ ! -d "$BACKUP_DIR" ]]; then
        run_cmd mkdir -p "$BACKUP_DIR"
        run_cmd chmod 700 "$BACKUP_DIR"
    fi

    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_name
    backup_name=$(basename "$file")
    local backup_path="$BACKUP_DIR/${backup_name}.${timestamp}"

    run_cmd cp -p "$file" "$backup_path"
    debug "Backed up $file to $backup_path"

    # Keep only last 10 backups of each file
    local old_backups
    old_backups=$(ls -t "$BACKUP_DIR/${backup_name}."* 2>/dev/null | tail -n +11)
    if [[ -n "$old_backups" ]]; then
        echo "$old_backups" | xargs rm -f
    fi
}

#######################################
# Restore a file from backup
# Arguments:
#   file: Original file path
#   backup: Specific backup file (optional, defaults to latest)
#######################################
restore_file() {
    local file="$1"
    local backup="${2:-}"

    if [[ -z "$backup" ]]; then
        # Find latest backup
        local backup_name
        backup_name=$(basename "$file")
        backup=$(ls -t "$BACKUP_DIR/${backup_name}."* 2>/dev/null | head -1)
    fi

    if [[ -z "$backup" || ! -f "$backup" ]]; then
        err "No backup found for: $file"
        return 1
    fi

    info "Restoring $file from $backup"
    run_cmd cp -p "$backup" "$file"
}

#######################################
# List available backups
#######################################
list_backups() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        info "No backups found"
        return
    fi

    info "Available backups in $BACKUP_DIR:"
    ls -lht "$BACKUP_DIR"
}
```

---

## Configuration Management

### Configuration Hierarchy (Precedence)

Configuration is loaded in layers. Later layers override earlier ones:

```
Priority (lowest to highest):
1. config/defaults.conf      # Base values, always loaded
2. config/{environment}.conf # Environment-specific (production, staging)
3. config/local.conf         # Machine-specific (gitignored)
4. Environment variables     # Runtime overrides (HIGHEST priority)
```

### Example: How Precedence Works

```bash
# config/defaults.conf
HUGEPAGES_COUNT=512

# config/production.conf
HUGEPAGES_COUNT=1024

# config/local.conf
HUGEPAGES_COUNT=2048

# Command line
HUGEPAGES_COUNT=4096 ./setup.sh

# Result: HUGEPAGES_COUNT=4096 (env var wins)
```

### Variable Patterns

```bash
# Pattern 1: Optional with sensible default
local timeout="${REQUEST_TIMEOUT:-30}"

# Pattern 2: Required - fail if not set
local api_key="${API_KEY:?API_KEY must be set}"

# Pattern 3: Optional, empty is OK
local custom_arg="${CUSTOM_ARG:-}"

# Pattern 4: Computed default (lazy evaluation)
local hostname="${CUSTOM_HOSTNAME:-$(hostname)}"

# Pattern 5: Boolean feature flags
if [[ "${ENABLE_RDMA:-true}" == "true" ]]; then
    configure_rdma
fi
```

### Configuration Validation

Always validate configuration values before use:

```bash
#######################################
# Validate all configuration values
#######################################
validate_config() {
    local errors=0

    # Numeric validation
    if ! [[ "${HUGEPAGES_COUNT:-512}" =~ ^[0-9]+$ ]]; then
        err "HUGEPAGES_COUNT must be numeric"
        ((errors++))
    fi

    # Range validation
    if [[ "${HUGEPAGES_COUNT:-512}" -lt 256 ]]; then
        warn "HUGEPAGES_COUNT < 256 may cause Rivermax failures"
    fi

    # CIDR validation
    if [[ -n "${EVT_CAMERA_SUBNET:-}" ]]; then
        assert_valid_cidr "$EVT_CAMERA_SUBNET"
    fi

    # Enum validation
    case "${PTP_TRANSPORT:-L2}" in
        L2|UDPv4|UDPv6) ;;
        *) err "Invalid PTP_TRANSPORT: ${PTP_TRANSPORT}"; ((errors++)) ;;
    esac

    return "$errors"
}
```

---

## Secrets Management

### Critical Rule

**Never commit secrets to git**, even in private repositories.

### Secure Secrets Loading

```bash
# lib/security.sh

#######################################
# Load secrets from external file with security checks
# Arguments:
#   secrets_file: Path to secrets file
#######################################
load_secrets() {
    local secrets_file="${1:-/etc/pulse/secrets.conf}"

    # Check file exists
    if [[ ! -f "$secrets_file" ]]; then
        debug "No secrets file at $secrets_file"
        return 0
    fi

    # SECURITY: Check file permissions (must be 600)
    local perms
    perms=$(stat -c '%a' "$secrets_file")
    if [[ "$perms" != "600" ]]; then
        fatal "Secrets file has insecure permissions: $perms (must be 600)"
    fi

    # SECURITY: Check ownership (must be root:root)
    local owner
    owner=$(stat -c '%U:%G' "$secrets_file")
    if [[ "$owner" != "root:root" ]]; then
        fatal "Secrets file has insecure ownership: $owner (must be root:root)"
    fi

    # Disable command tracing while loading secrets
    local old_opts="$-"
    set +x

    # shellcheck source=/dev/null
    source "$secrets_file"

    # Restore tracing if it was enabled
    [[ "$old_opts" == *x* ]] && set -x

    debug "Loaded secrets from $secrets_file"
}

#######################################
# Clear sensitive variables from environment
#######################################
clear_secrets() {
    unset DB_PASSWORD API_KEY SECRET_TOKEN
    debug "Cleared sensitive variables"
}
```

### .gitignore for Secrets

```gitignore
# Never commit these
config/local.conf
*.key
*.pem
*.secret
*.credentials
credentials/
.env
.env.*
!.env.example
secrets.conf
```

---

## Security Hardening

### Input Validation

Always validate untrusted input:

```bash
#######################################
# Validate and sanitize interface name
# Prevents path traversal attacks
#######################################
sanitize_interface_name() {
    local iface="$1"

    # Only allow safe characters
    if [[ ! "$iface" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        fatal "Invalid interface name: $iface"
    fi

    # Verify it exists
    if [[ ! -d "/sys/class/net/$iface" ]]; then
        fatal "Interface does not exist: $iface"
    fi

    echo "$iface"
}

# Usage
local iface
iface=$(sanitize_interface_name "$USER_INPUT")
cat "/sys/class/net/$iface/address"  # Now safe
```

### File Operations

```bash
#######################################
# Create config file with secure permissions
# Arguments:
#   file_path: Destination path
#   permissions: File mode (default: 644)
#   owner: Owner:group (default: root:root)
# Stdin: File content
#######################################
create_config_file() {
    local file_path="$1"
    local permissions="${2:-644}"
    local owner="${3:-root:root}"

    # Create parent directory if needed
    local parent_dir
    parent_dir=$(dirname "$file_path")
    if [[ ! -d "$parent_dir" ]]; then
        mkdir -p "$parent_dir"
        chmod 755 "$parent_dir"
    fi

    # Write to temp file first
    local temp_file
    temp_file=$(mktemp)

    # Read content from stdin
    cat > "$temp_file"

    # Set permissions BEFORE moving to final location
    chmod "$permissions" "$temp_file"
    chown "$owner" "$temp_file"

    # Atomic move
    mv "$temp_file" "$file_path"

    debug "Created $file_path with mode $permissions owner $owner"
}

# Usage
process_template "$template" /dev/stdout | \
    create_config_file "/etc/myapp.conf" "640" "root:myapp"
```

### Audit Logging

```bash
# lib/audit.sh

readonly AUDIT_LOG="${AUDIT_LOG:-/var/log/pulse-deploy/audit.log}"

#######################################
# Write audit log entry
#######################################
audit_log() {
    local action="$1"
    local status="$2"
    local details="${3:-}"

    local timestamp
    timestamp=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    local user="${SUDO_USER:-$(whoami)}"
    local host
    host=$(hostname)

    # Ensure log directory exists
    local log_dir
    log_dir=$(dirname "$AUDIT_LOG")
    [[ -d "$log_dir" ]] || mkdir -p "$log_dir"

    # Format: ISO timestamp | host | user | action | status | details
    printf '%s | %s | %s | %s | %s | %s\n' \
        "$timestamp" "$host" "$user" "$action" "$status" "$details" \
        >> "$AUDIT_LOG"

    # Secure the log file
    chmod 640 "$AUDIT_LOG"
}

# Usage in modules:
audit_log "INSTALL" "start" "module=network"
# ... do work ...
audit_log "INSTALL" "success" "module=network files_changed=2"
```

---

## Hardware Detection

### ConnectX-6 Detection

```bash
# lib/detect.sh

readonly VENDOR_MELLANOX="0x15b3"

# ConnectX-6 device IDs
readonly DEVICE_CX6="0x101b"
readonly DEVICE_CX6_DX="0x101d"
readonly DEVICE_CX6_LX="0x101f"

#######################################
# Detect Mellanox interface by vendor ID
# Outputs: Interface name
# Returns: 0 if found, 1 if not
#######################################
detect_mellanox_interface() {
    local iface name vendor_file

    for iface in /sys/class/net/*; do
        name=$(basename "$iface")
        [[ "$name" == "lo" ]] && continue

        vendor_file="$iface/device/vendor"
        [[ -f "$vendor_file" ]] || continue

        if [[ "$(cat "$vendor_file")" == "$VENDOR_MELLANOX" ]]; then
            echo "$name"
            return 0
        fi
    done
    return 1
}

#######################################
# Get ConnectX device model
# Arguments: interface name
# Outputs: Device model (cx6, cx6dx, cx6lx, unknown)
#######################################
get_cx_model() {
    local iface="$1"
    local device_file="/sys/class/net/$iface/device/device"

    [[ -f "$device_file" ]] || { echo "unknown"; return; }

    local device_id
    device_id=$(cat "$device_file")

    case "$device_id" in
        "$DEVICE_CX6") echo "cx6" ;;
        "$DEVICE_CX6_DX") echo "cx6dx" ;;
        "$DEVICE_CX6_LX") echo "cx6lx" ;;
        *) echo "unknown" ;;
    esac
}

#######################################
# Get firmware version
# Arguments: interface name
# Outputs: Firmware version string
#######################################
get_firmware_version() {
    local iface="$1"

    if ! command -v ethtool &>/dev/null; then
        echo "unknown"
        return
    fi

    ethtool -i "$iface" 2>/dev/null | awk -F': ' '/firmware-version/ {print $2}'
}

#######################################
# Check if interface supports hardware timestamping
# Arguments: interface name
# Returns: 0 if supported, 1 if not
#######################################
supports_hardware_timestamp() {
    local iface="$1"

    ethtool -T "$iface" 2>/dev/null | grep -q "hardware-raw-clock"
}

#######################################
# Check if interface is PF passthrough in VM
#######################################
is_pf_passthrough() {
    local iface="$1"
    local driver_link="/sys/class/net/$iface/device/driver"

    [[ -L "$driver_link" ]] || return 1

    local driver
    driver=$(basename "$(readlink "$driver_link")")

    # If using native mlx5_core driver in a VM, it's passthrough
    [[ "$driver" == "mlx5_core" ]] && [[ "$(detect_virtualization)" != "none" ]]
}

#######################################
# Check if interface is SR-IOV VF
#######################################
is_virtual_function() {
    local iface="$1"
    [[ -L "/sys/class/net/$iface/device/physfn" ]]
}

#######################################
# Get NUMA node for interface
#######################################
get_numa_node() {
    local iface="$1"
    local numa_file="/sys/class/net/$iface/device/numa_node"

    if [[ -f "$numa_file" ]]; then
        cat "$numa_file"
    else
        echo "-1"
    fi
}

#######################################
# Detect virtualization type
#######################################
detect_virtualization() {
    if command -v systemd-detect-virt &>/dev/null; then
        systemd-detect-virt 2>/dev/null || echo "none"
        return
    fi

    if [[ -f /sys/class/dmi/id/product_name ]]; then
        local product
        product=$(cat /sys/class/dmi/id/product_name)
        case "$product" in
            *"Virtual Machine"*) echo "hyperv"; return ;;
            *"VMware"*) echo "vmware"; return ;;
            *"QEMU"*|*"KVM"*) echo "kvm"; return ;;
        esac
    fi

    [[ -f /.dockerenv ]] && { echo "docker"; return; }

    echo "none"
}
```

---

## RDMA and Rivermax Configuration

### RDMA Detection and Setup

```bash
# lib/rdma.sh - RDMA-specific helpers

#######################################
# Check if RDMA subsystem is available
#######################################
is_rdma_available() {
    [[ -d /sys/class/infiniband ]]
}

#######################################
# Get RDMA device for network interface
# Arguments: interface name
# Outputs: RDMA device name (e.g., mlx5_0)
#######################################
get_rdma_device() {
    local iface="$1"

    # Find RDMA device that corresponds to this interface
    for rdma_dev in /sys/class/infiniband/*; do
        local dev_name
        dev_name=$(basename "$rdma_dev")

        # Check if this RDMA device is associated with our interface
        if [[ -d "$rdma_dev/device/net/$iface" ]]; then
            echo "$dev_name"
            return 0
        fi
    done
    return 1
}

#######################################
# Verify RDMA device capabilities for Rivermax
# Arguments: RDMA device name
# Returns: 0 if suitable, 1 if not
#######################################
verify_rdma_capabilities() {
    local rdma_dev="$1"
    local errors=0

    # Check device exists
    if [[ ! -d "/sys/class/infiniband/$rdma_dev" ]]; then
        err "RDMA device not found: $rdma_dev"
        return 1
    fi

    # Check for raw packet QP support (needed for Rivermax)
    if command -v ibv_devinfo &>/dev/null; then
        if ! ibv_devinfo -d "$rdma_dev" 2>/dev/null | grep -q "RAW_PACKET"; then
            warn "RDMA device may not support RAW_PACKET QPs"
            ((errors++))
        fi
    fi

    return "$errors"
}

#######################################
# Configure memory limits for RDMA
# Rivermax requires ability to lock large amounts of memory
#######################################
configure_rdma_limits() {
    local limits_file="/etc/security/limits.d/99-rdma.conf"

    info "Configuring RDMA memory limits"

    cat > "$limits_file" << 'EOF'
# RDMA memory locking limits for Rivermax
# Allow unlimited locked memory for users in 'rdma' group
@rdma    soft    memlock    unlimited
@rdma    hard    memlock    unlimited

# Root also needs unlimited for setup
root     soft    memlock    unlimited
root     hard    memlock    unlimited
EOF

    chmod 644 "$limits_file"

    # Create rdma group if it doesn't exist
    if ! getent group rdma &>/dev/null; then
        groupadd rdma
        info "Created 'rdma' group"
    fi
}
```

### Rivermax Environment Setup

```bash
# modules/rdma/install.sh

#######################################
# Configure environment for Rivermax SDK
#######################################
configure_rivermax_env() {
    local env_file="/etc/profile.d/rivermax.sh"

    info "[rdma] Creating Rivermax environment file"

    cat > "$env_file" << 'EOF'
# Rivermax SDK environment
# Loaded automatically on login

# RDMA device selection (auto-detect if not set)
# export MLX5_RDMA_DEVICE=mlx5_0

# Rivermax performance tuning
export RIVERMAX_ENABLE_AUTOPILOT=1
export RIVERMAX_LOG_LEVEL=3

# Memory management
export MLX5_SINGLE_THREADED=1
export MLX5_SCATTER_TO_CQE=0

# Packet pacing (for video streaming)
export RIVERMAX_PACKET_PACING=1
EOF

    chmod 644 "$env_file"
}

#######################################
# Verify Rivermax prerequisites
#######################################
verify_rivermax_ready() {
    local errors=0

    info "Verifying Rivermax prerequisites..."

    # Check RDMA
    if ! is_rdma_available; then
        err "RDMA subsystem not available"
        ((errors++))
    fi

    # Check hugepages
    local hugepages
    hugepages=$(awk '/HugePages_Total/ {print $2}' /proc/meminfo)
    if [[ "$hugepages" -lt 256 ]]; then
        err "Insufficient hugepages: $hugepages (need at least 256)"
        ((errors++))
    fi

    # Check memlock limits
    local memlock
    memlock=$(ulimit -l)
    if [[ "$memlock" != "unlimited" && "$memlock" -lt 1048576 ]]; then
        warn "Low memlock limit: $memlock KB (recommend unlimited)"
    fi

    # Check for Mellanox interface
    if ! detect_mellanox_interface &>/dev/null; then
        err "No Mellanox interface detected"
        ((errors++))
    fi

    if [[ $errors -eq 0 ]]; then
        info "Rivermax prerequisites verified"
    else
        err "Rivermax verification failed with $errors error(s)"
    fi

    return "$errors"
}
```

### NUMA-Aware Hugepage Allocation

```bash
# modules/hugepages/install.sh additions

#######################################
# Allocate hugepages on specific NUMA node
# Arguments:
#   numa_node: NUMA node number
#   count: Number of hugepages
#######################################
allocate_numa_hugepages() {
    local numa_node="$1"
    local count="$2"

    local hp_path="/sys/devices/system/node/node${numa_node}/hugepages/hugepages-2048kB/nr_hugepages"

    if [[ ! -f "$hp_path" ]]; then
        warn "NUMA node $numa_node hugepages path not found, falling back to global"
        echo "$count" > /proc/sys/vm/nr_hugepages
        return
    fi

    info "Allocating $count hugepages on NUMA node $numa_node"
    echo "$count" > "$hp_path"

    # Verify allocation
    local allocated
    allocated=$(cat "$hp_path")
    if [[ "$allocated" -lt "$count" ]]; then
        warn "Only allocated $allocated of $count hugepages on NUMA $numa_node"
        warn "System may be fragmented - consider rebooting"
    fi
}

#######################################
# Auto-detect NUMA node from Mellanox interface and allocate hugepages
#######################################
auto_configure_hugepages() {
    local count="${HUGEPAGES_COUNT:-512}"

    local mlx_iface
    if mlx_iface=$(detect_mellanox_interface); then
        local numa_node
        numa_node=$(get_numa_node "$mlx_iface")

        if [[ "$numa_node" != "-1" ]]; then
            info "Detected Mellanox on NUMA node $numa_node"
            allocate_numa_hugepages "$numa_node" "$count"
            return
        fi
    fi

    # Fallback to global allocation
    info "Allocating $count hugepages globally"
    echo "$count" > /proc/sys/vm/nr_hugepages
}
```

---

## Testing and Validation

### Bats Testing

```bash
#!/usr/bin/env bats
# tests/test_network.bats

setup() {
    load 'test_helpers'

    # Source libraries (don't execute them)
    source "$REPO_ROOT/lib/common.sh"
    source "$REPO_ROOT/lib/detect.sh"
    source "$REPO_ROOT/lib/assert.sh"
}

@test "detect_mellanox_interface returns interface name" {
    if ! detect_mellanox_interface &>/dev/null; then
        skip "No Mellanox interface available"
    fi

    run detect_mellanox_interface
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[a-z] ]]
}

@test "assert_valid_ipv4 accepts valid IPs" {
    run assert_valid_ipv4 "192.168.1.1"
    [ "$status" -eq 0 ]

    run assert_valid_ipv4 "10.0.0.1"
    [ "$status" -eq 0 ]
}

@test "assert_valid_ipv4 rejects invalid IPs" {
    run assert_valid_ipv4 "256.1.1.1"
    [ "$status" -ne 0 ]

    run assert_valid_ipv4 "not-an-ip"
    [ "$status" -ne 0 ]
}

@test "assert_valid_interface_name rejects path traversal" {
    run assert_valid_interface_name "../../../etc/passwd"
    [ "$status" -ne 0 ]

    run assert_valid_interface_name "eth0; rm -rf /"
    [ "$status" -ne 0 ]
}

@test "DRY_RUN prevents actual changes" {
    local test_file="$BATS_TMPDIR/test_dryrun"

    DRY_RUN=1 run_cmd touch "$test_file"

    [ ! -f "$test_file" ]
}

@test "module install is idempotent" {
    require_root

    run "$REPO_ROOT/modules/hugepages/install.sh"
    local first_status=$status
    [ "$first_status" -eq 0 ] || [ "$first_status" -eq 2 ]

    run "$REPO_ROOT/modules/hugepages/install.sh"
    local second_status=$status
    [ "$second_status" -eq 0 ] || [ "$second_status" -eq 2 ]
}
```

### Test Helpers

```bash
# tests/test_helpers.bash

# Repository root
export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"

# Set LIB_DIR for libraries that need it
export LIB_DIR="$REPO_ROOT/lib"

#######################################
# Skip test if not running as root
#######################################
require_root() {
    if [[ $EUID -ne 0 ]]; then
        skip "Test requires root privileges"
    fi
}

#######################################
# Skip test if no Mellanox hardware
#######################################
require_mellanox() {
    source "$REPO_ROOT/lib/detect.sh"
    if ! detect_mellanox_interface &>/dev/null; then
        skip "Test requires Mellanox hardware"
    fi
}

#######################################
# Assert file contains pattern
#######################################
assert_file_contains() {
    local file="$1"
    local pattern="$2"

    if ! grep -q "$pattern" "$file"; then
        echo "File $file does not contain: $pattern" >&2
        return 1
    fi
}

#######################################
# Create temporary test environment
#######################################
setup_test_env() {
    export TEST_CONFIG_DIR="$BATS_TMPDIR/config"
    mkdir -p "$TEST_CONFIG_DIR"

    echo 'TEST_VAR="from_defaults"' > "$TEST_CONFIG_DIR/defaults.conf"
}
```

---

## Backup and Recovery

### Rollback Strategy

```bash
# hooks/rollback.sh

#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/backup.sh"

#######################################
# Rollback all modules to their backup state
#######################################
rollback_all() {
    info "=== Starting Rollback ==="

    list_backups

    # Restore each backed-up file
    for backup in "$BACKUP_DIR"/*; do
        [[ -f "$backup" ]] || continue

        local original_name
        original_name=$(basename "$backup" | sed 's/\.[0-9]\{8\}-[0-9]\{6\}$//')

        # Determine original path (this is simplified - real impl would track paths)
        info "Would restore: $original_name from $backup"
    done

    warn "Rollback requires manual verification"
    warn "Review backups in: $BACKUP_DIR"
}

main() {
    require_root
    rollback_all
}

main "$@"
```

---

## Troubleshooting

### Common Issues

#### RDMA/Rivermax Issues

**Problem**: Rivermax fails with "unable to allocate memory"

**Symptoms**:
```
RIVERMAX: Error: Failed to allocate memory for internal buffers
```

**Solutions**:
1. Check hugepages: `grep Huge /proc/meminfo`
2. Check memlock limits: `ulimit -l`
3. Verify NUMA locality: hugepages should be on same NUMA node as NIC
4. Try increasing `HUGEPAGES_COUNT` in config

**Problem**: "No RDMA device found"

**Diagnosis**:
```bash
# Check RDMA devices
ls /sys/class/infiniband/

# Check driver loaded
lsmod | grep mlx5

# Check interface RDMA binding
ibv_devinfo
```

#### PTP Synchronization Issues

**Problem**: PTP offset too high (>1ms)

**Diagnosis**:
```bash
# Check PTP status
sudo journalctl -u ptp4l -f

# Check hardware timestamp support
ethtool -T enp2s0f0np0 | grep -i hardware
```

**Solutions**:
1. Verify grandmaster is reachable on same L2 network
2. Check PTP domain matches grandmaster
3. Verify hardware timestamping is enabled
4. Check for network congestion or asymmetric paths

#### Network Configuration Issues

**Problem**: Interface not detected

**Diagnosis**:
```bash
# List all interfaces
ip link show

# Check for Mellanox by vendor
for iface in /sys/class/net/*; do
    vendor=$(cat "$iface/device/vendor" 2>/dev/null)
    echo "$(basename $iface): $vendor"
done
```

### Debug Mode

Run any script with detailed logging:

```bash
DEBUG=1 ./setup.sh
DEBUG=1 ./modules/network/install.sh
```

### Dry Run

Preview changes without modifying the system:

```bash
DRY_RUN=1 ./setup.sh
```

---

## Agent Instructions

### Decision Trees

When working with this repository, AI agents should use these decision trees:

#### Decision: Should I modify this file?

```
Is file in lib/?
├── YES → Changes affect ALL modules
│   ├── Is it a bug fix? → Proceed with caution, test thoroughly
│   └── Is it a new feature? → Consider adding to new file instead
└── NO → Is file in modules/<name>/?
    ├── YES → Changes isolated to this module
    │   └── Proceed, ensure idempotency maintained
    └── NO → Is file in config/?
        ├── YES → Is it defaults.conf?
        │   ├── YES → Safe to add new defaults
        │   └── NO → Environment-specific, be careful
        └── NO → Check docs/ or other locations
```

#### Decision: When to stop and ask

**STOP and ask the user if:**
1. Modifying `lib/common.sh` or `lib/assert.sh` (affects everything)
2. Changing exit codes or return value semantics
3. Adding new required dependencies
4. Removing functionality (breaking change)
5. Test failures occur
6. Security-sensitive changes (secrets, permissions)
7. Unclear requirements or multiple valid approaches

**Proceed autonomously if:**
1. Adding new module (follows template)
2. Fixing clear bug with obvious solution
3. Adding validation or error handling
4. Improving logging or documentation
5. Changes isolated to single module

#### Decision: Module dependencies

```
Module dependency order:
kernel      → (no dependencies)
hugepages   → (no dependencies)
network     → kernel
ptp         → network
rdma        → network, hugepages
evt         → network, ptp, rdma
```

### Discovery Phase

Before making any changes:

1. **Read `README.md`** for project overview
2. **Read this guide** for conventions and patterns
3. **Identify the relevant module** in `modules/`
4. **Check `lib/`** for existing utilities to reuse
5. **Review `config/defaults.conf`** for configuration options

### Modification Phase

When writing code:

1. **Source `lib/common.sh`** at the top of every script
2. **Use existing functions** - don't reinvent
3. **Follow the module contract** - idempotent, proper exit codes
4. **Validate inputs** using `lib/assert.sh` functions
5. **Backup before modifying** using `lib/backup.sh`
6. **Use templates** for files needing variable substitution
7. **Use `local`** for all function variables
8. **Use `readonly`** for constants

### Validation Phase

After making changes:

1. **Check syntax**: `bash -n script.sh`
2. **Run shellcheck**: `shellcheck script.sh`
3. **Test with DRY_RUN**: `DRY_RUN=1 ./script.sh`
4. **Test idempotency**: Run twice, second run should exit 2
5. **Run tests**: `bats tests/`

### Anti-Patterns to Avoid

```bash
# DON'T: Hardcode paths
cp file.txt /home/user/config  # BAD

# DO: Use variables
cp file.txt "$REPO_ROOT/config"  # GOOD

# DON'T: Use global variables in functions
MY_VAR="value"
my_func() { echo "$MY_VAR"; }  # BAD - relies on global

# DO: Use local variables and parameters
my_func() {
    local my_var="$1"
    echo "$my_var"
}  # GOOD

# DON'T: Execute library files
./lib/common.sh  # BAD - will fail or do nothing useful

# DO: Source library files
source "$REPO_ROOT/lib/common.sh"  # GOOD

# DON'T: Use echo for errors
echo "Error: something failed"  # BAD - goes to stdout

# DO: Use logging functions
err "Something failed"  # GOOD - goes to stderr with formatting

# DON'T: Ignore exit codes
some_command
# continue regardless  # BAD

# DO: Check exit codes
if ! some_command; then
    err "Command failed"
    return 1
fi  # GOOD

# DON'T: Use envsubst without variable whitelist
envsubst < template > output  # BAD - substitutes ALL env vars (including secrets)

# DO: Whitelist variables
envsubst '$VAR1 $VAR2' < template > output  # GOOD
```

### Common Patterns

**Adding a new configuration option:**
```
1. Add default to config/defaults.conf
2. Document in relevant module README
3. Use in scripts via ${VAR_NAME:-default}
4. Add validation in validate_config()
```

**Adding a new module:**
```
1. Create modules/<name>/ directory
2. Create metadata.sh with version and dependencies
3. Create install.sh following module contract
4. Create README.md with usage documentation
5. Add to MODULES array in setup.sh
6. Add tests in tests/test_<name>.bats
```

---

## References

### IaC and Repository Structure
- [IaC Best Practices 2024](https://daily.dev/blog/iac-best-practices-developer-guide-2024)
- [Flux CD Repository Structure](https://fluxcd.io/flux/guides/repository-structure/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/2.8/user_guide/playbooks_best_practices.html)

### Shell Scripting
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Bash-Commons Library](https://github.com/gruntwork-io/bash-commons)
- [Bats-Core Testing Framework](https://bats-core.readthedocs.io/)

### RDMA and Networking
- [NVIDIA Network Operator](https://github.com/Mellanox/network-operator)
- [Rivermax SDK Documentation](https://developer.nvidia.com/networking/rivermax)
- [RDMA Programming Guide](https://www.rdmamojo.com/)

### Real-Time and PTP
- [Meta's PTP at Scale](https://engineering.fb.com/2022/11/21/production-engineering/precision-time-protocol-at-meta/)
- [Red Hat PTP Configuration](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/system_administrators_guide/ch-configuring_ptp_using_ptp4l)
- [LinuxPTP Project](https://linuxptp.sourceforge.net/)

### Security
- [Secrets Management - OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks)
