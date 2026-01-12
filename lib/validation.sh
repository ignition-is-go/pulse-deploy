#!/bin/bash
# lib/validation.sh - Input and state validation utilities
# Usage: source "$REPO_ROOT/lib/validation.sh"
#
# This is a library file. Do not execute directly.

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: This script is a library and should be sourced, not executed" >&2
    exit 1
fi

#######################################
# Validate IP address format
# Arguments:
#   ip: IP address to validate
# Returns:
#   0 if valid, 1 otherwise
#######################################
validate_ip() {
    local ip="$1"
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

    if [[ ! $ip =~ $regex ]]; then
        return 1
    fi

    # Validate each octet
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if (( octet > 255 )); then
            return 1
        fi
    done
    return 0
}

#######################################
# Validate CIDR notation
# Arguments:
#   cidr: CIDR to validate (e.g., 10.0.0.1/24)
# Returns:
#   0 if valid, 1 otherwise
#######################################
validate_cidr() {
    local cidr="$1"
    local ip prefix

    if [[ ! $cidr =~ ^.+/[0-9]+$ ]]; then
        return 1
    fi

    ip="${cidr%/*}"
    prefix="${cidr#*/}"

    validate_ip "$ip" || return 1

    if (( prefix < 0 || prefix > 32 )); then
        return 1
    fi
    return 0
}

#######################################
# Validate MAC address format
# Arguments:
#   mac: MAC address to validate
# Returns:
#   0 if valid, 1 otherwise
#######################################
validate_mac() {
    local mac="$1"
    local regex='^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$'

    [[ $mac =~ $regex ]]
}

#######################################
# Validate interface exists
# Arguments:
#   interface: Interface name to validate
# Returns:
#   0 if exists, 1 otherwise
#######################################
validate_interface() {
    local iface="$1"
    [[ -d "/sys/class/net/$iface" ]]
}

#######################################
# Validate positive integer
# Arguments:
#   value: Value to validate
# Returns:
#   0 if valid positive integer, 1 otherwise
#######################################
validate_positive_int() {
    local value="$1"
    [[ $value =~ ^[1-9][0-9]*$ ]]
}

#######################################
# Validate non-negative integer
# Arguments:
#   value: Value to validate
# Returns:
#   0 if valid non-negative integer, 1 otherwise
#######################################
validate_non_negative_int() {
    local value="$1"
    [[ $value =~ ^[0-9]+$ ]]
}

#######################################
# Validate path is safe (no traversal)
# Arguments:
#   path: Path to validate
# Returns:
#   0 if safe, 1 otherwise
#######################################
validate_path_safe() {
    local path="$1"

    # Block path traversal
    if [[ "$path" == *".."* ]]; then
        return 1
    fi

    # Block null bytes
    if [[ "$path" == *$'\0'* ]]; then
        return 1
    fi

    return 0
}

#######################################
# Validate port number
# Arguments:
#   port: Port number to validate
# Returns:
#   0 if valid (1-65535), 1 otherwise
#######################################
validate_port() {
    local port="$1"

    if ! [[ $port =~ ^[0-9]+$ ]]; then
        return 1
    fi

    (( port >= 1 && port <= 65535 ))
}

#######################################
# Pre-flight Check Functions
#######################################

#######################################
# Run standard pre-flight checks
# Globals:
#   REQUIRED_COMMANDS - array of required commands
#   REQUIRED_FILES - array of required files
# Returns:
#   0 if all pass, 1 on failure
#######################################
preflight_check() {
    local failed=0

    # Check required commands
    if [[ -n "${REQUIRED_COMMANDS[*]:-}" ]]; then
        for cmd in "${REQUIRED_COMMANDS[@]}"; do
            if ! command -v "$cmd" &>/dev/null; then
                err "Required command not found: $cmd"
                ((failed++))
            fi
        done
    fi

    # Check required files
    if [[ -n "${REQUIRED_FILES[*]:-}" ]]; then
        for file in "${REQUIRED_FILES[@]}"; do
            if [[ ! -f "$file" ]]; then
                err "Required file not found: $file"
                ((failed++))
            fi
        done
    fi

    # Check not in container (if system config needed)
    if [[ "${REQUIRE_BARE_METAL:-0}" == "1" ]]; then
        if is_container; then
            err "This script must run on bare metal, not in a container"
            ((failed++))
        fi
    fi

    return $((failed > 0 ? 1 : 0))
}

#######################################
# Assert a condition or fail
# Arguments:
#   condition: Condition to test
#   message: Error message if condition fails
# Returns:
#   0 if condition true, exits on failure
#######################################
assert() {
    local condition="$1"
    local message="${2:-Assertion failed}"

    if ! eval "$condition"; then
        fatal "Assertion failed: $message"
    fi
}

#######################################
# Assert variable is set and non-empty
# Arguments:
#   var_name: Name of variable to check
#   description: Human-readable description for error
# Returns:
#   0 if set, exits on failure
#######################################
assert_var() {
    local var_name="$1"
    local description="${2:-$var_name}"

    if [[ -z "${!var_name:-}" ]]; then
        fatal "Required variable not set: $description ($var_name)"
    fi
}

#######################################
# Assert file exists
# Arguments:
#   file_path: Path to file
#   description: Human-readable description
# Returns:
#   0 if exists, exits on failure
#######################################
assert_file() {
    local file="$1"
    local description="${2:-$file}"

    if [[ ! -f "$file" ]]; then
        fatal "Required file not found: $description ($file)"
    fi
}

#######################################
# Assert directory exists
# Arguments:
#   dir_path: Path to directory
#   description: Human-readable description
# Returns:
#   0 if exists, exits on failure
#######################################
assert_dir() {
    local dir="$1"
    local description="${2:-$dir}"

    if [[ ! -d "$dir" ]]; then
        fatal "Required directory not found: $description ($dir)"
    fi
}

#######################################
# Assert command exists
# Arguments:
#   command: Command name
#   package_hint: Optional hint for installing
# Returns:
#   0 if exists, exits on failure
#######################################
assert_command() {
    local cmd="$1"
    local hint="${2:-}"

    if ! command -v "$cmd" &>/dev/null; then
        local msg="Required command not found: $cmd"
        if [[ -n "$hint" ]]; then
            msg+=". Install with: $hint"
        fi
        fatal "$msg"
    fi
}
