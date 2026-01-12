#!/bin/bash
# lib/common.sh - Core utilities for deployment scripts
# Usage: source "$REPO_ROOT/lib/common.sh"
#
# This is a library file. Do not execute directly.

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: This script is a library and should be sourced, not executed" >&2
    exit 1
fi

# Ensure REPO_ROOT is set
if [[ -z "${REPO_ROOT:-}" ]]; then
    echo "ERROR: REPO_ROOT must be set before sourcing common.sh" >&2
    return 1
fi

#######################################
# Logging Configuration
#######################################

# Enable timestamps (override with DEPLOY_LOG_TIMESTAMPS=0)
readonly LOG_TIMESTAMPS="${DEPLOY_LOG_TIMESTAMPS:-1}"

# Color output (auto-detect, override with DEPLOY_LOG_COLOR=0|1)
if [[ -t 1 && "${DEPLOY_LOG_COLOR:-1}" != "0" ]]; then
    readonly _LOG_RED='\033[0;31m'
    readonly _LOG_YELLOW='\033[0;33m'
    readonly _LOG_GREEN='\033[0;32m'
    readonly _LOG_CYAN='\033[0;36m'
    readonly _LOG_NC='\033[0m'
else
    readonly _LOG_RED=''
    readonly _LOG_YELLOW=''
    readonly _LOG_GREEN=''
    readonly _LOG_CYAN=''
    readonly _LOG_NC=''
fi

#######################################
# Format log message with optional timestamp
# Globals:
#   LOG_TIMESTAMPS
# Arguments:
#   level: Log level string
#   message: Log message
# Outputs:
#   Formatted log line to stdout
#######################################
_log_format() {
    local level="$1"
    shift
    local message="$*"

    if [[ "$LOG_TIMESTAMPS" == "1" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
    else
        echo "[$level] $message"
    fi
}

#######################################
# Log info message
# Arguments:
#   message: Message to log
#######################################
info() {
    echo -e "${_LOG_GREEN}$(_log_format INFO "$@")${_LOG_NC}"
}

#######################################
# Log warning message
# Arguments:
#   message: Message to log
#######################################
warn() {
    echo -e "${_LOG_YELLOW}$(_log_format WARN "$@")${_LOG_NC}" >&2
}

#######################################
# Log error message
# Arguments:
#   message: Message to log
#######################################
err() {
    echo -e "${_LOG_RED}$(_log_format ERROR "$@")${_LOG_NC}" >&2
}

#######################################
# Log error and exit
# Arguments:
#   message: Message to log
# Returns:
#   Never returns, exits with code 1
#######################################
fatal() {
    err "$@"
    exit 1
}

#######################################
# Log debug message (only when DEPLOY_DEBUG=1)
# Arguments:
#   message: Message to log
#######################################
debug() {
    if [[ "${DEPLOY_DEBUG:-0}" == "1" ]]; then
        echo -e "${_LOG_CYAN}$(_log_format DEBUG "$@")${_LOG_NC}" >&2
    fi
}

#######################################
# Root/Sudo Handling
#######################################

# Populated by require_root()
SUDO=""

#######################################
# Ensure script has root privileges
# Does NOT use exec - safe for sourced scripts
# Globals:
#   SUDO - set to "sudo" if needed, empty if already root
# Returns:
#   0 if root access available, exits on failure
#######################################
require_root() {
    if [[ $EUID -eq 0 ]]; then
        SUDO=""
        return 0
    fi

    # Check if we're running under sudo already
    if [[ -n "${SUDO_USER:-}" ]]; then
        SUDO=""
        return 0
    fi

    # Not root, need sudo
    if ! command -v sudo &>/dev/null; then
        fatal "This script requires root privileges and sudo is not available"
    fi

    if ! sudo -v &>/dev/null; then
        fatal "This script requires root privileges. Run with: sudo $0"
    fi

    SUDO="sudo"
}

#######################################
# Dry Run Support
#######################################

#######################################
# Execute command (or just print in dry-run mode)
# Globals:
#   DRY_RUN
#   SUDO
# Arguments:
#   command and arguments
# Returns:
#   0 if dry run or command succeeds
#######################################
run() {
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        info "[DRY-RUN] Would execute: $*"
        return 0
    fi
    "$@"
}

#######################################
# Execute command with sudo (or just print in dry-run mode)
# Globals:
#   DRY_RUN
#   SUDO
# Arguments:
#   command and arguments
#######################################
run_sudo() {
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        info "[DRY-RUN] Would execute (as root): $*"
        return 0
    fi
    $SUDO "$@"
}

#######################################
# Utility Functions
#######################################

#######################################
# Check if a command exists
# Arguments:
#   command_name: Name of command to check
# Returns:
#   0 if exists, 1 otherwise
#######################################
command_exists() {
    command -v "$1" &>/dev/null
}

#######################################
# Check if running in a container
# Returns:
#   0 if in container, 1 otherwise
#######################################
is_container() {
    [[ -f /.dockerenv ]] || grep -q 'docker\|lxc\|containerd' /proc/1/cgroup 2>/dev/null
}

#######################################
# Get distribution info
# Outputs:
#   Distribution ID (ubuntu, debian, fedora, etc.)
#######################################
get_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        echo "${ID:-unknown}"
    else
        echo "unknown"
    fi
}

#######################################
# Wait for a condition with timeout
# Arguments:
#   timeout_seconds: Max seconds to wait
#   check_command: Command to run (success = done)
#   message: Optional message to display
# Returns:
#   0 if condition met, 1 if timeout
#######################################
wait_for() {
    local timeout="$1"
    local check_cmd="$2"
    local message="${3:-Waiting...}"

    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if eval "$check_cmd" &>/dev/null; then
            return 0
        fi
        debug "$message ($elapsed/$timeout seconds)"
        sleep 1
        ((elapsed++))
    done
    return 1
}

#######################################
# Backup a file before modifying
# Arguments:
#   file_path: Path to file to backup
# Returns:
#   0 if backup created or file doesn't exist
#######################################
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.bak.$(date +%Y%m%d_%H%M%S)"
        run_sudo cp "$file" "$backup"
        debug "Backed up $file to $backup"
    fi
}

#######################################
# Template Processing
#######################################

#######################################
# Process a template file with variable substitution
# SECURITY: Only substitutes explicitly listed variables
# Arguments:
#   template: Path to template file
#   output: Path to output file
#   variables: Space-separated list of variables (e.g., '$VAR1 $VAR2')
# Returns:
#   0 on success, 1 on failure
#######################################
process_template() {
    local template="$1"
    local output="$2"
    local variables="${3:-}"

    if [[ ! -f "$template" ]]; then
        err "Template not found: $template"
        return 1
    fi

    if [[ -z "$variables" ]]; then
        err "process_template requires explicit variable list for security"
        err "Usage: process_template template output '\$VAR1 \$VAR2'"
        return 1
    fi

    debug "Processing template: $template -> $output"
    debug "Variables: $variables"

    envsubst "$variables" < "$template" > "$output"
}

#######################################
# Module Status
#######################################

# Exit code for "already configured, no changes needed"
readonly EXIT_ALREADY_CONFIGURED=2

#######################################
# Report that module is already configured
# Arguments:
#   module_name: Name of the module
# Returns:
#   Exits with EXIT_ALREADY_CONFIGURED
#######################################
already_configured() {
    local module="${1:-module}"
    info "[$module] Already configured - no changes needed"
    exit $EXIT_ALREADY_CONFIGURED
}
