#!/bin/bash
# setup.sh - Main orchestrator for Pulse cluster node deployment
#
# Usage:
#   ./setup.sh                  # Full deployment
#   DRY_RUN=1 ./setup.sh        # Preview changes without applying
#   DEPLOY_DEBUG=1 ./setup.sh   # Verbose output
#   ./setup.sh --module ptp     # Run specific module only
#
# Environment:
#   See config/defaults.conf for all configuration options
#
# Exit codes:
#   0 - Success
#   1 - Error
#   2 - Already configured (when running single module)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="$SCRIPT_DIR"

# Load libraries
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/validation.sh"

# Load configuration
source "$REPO_ROOT/config/defaults.conf"

#######################################
# Module execution order (respects dependencies)
#######################################
readonly MODULES=(
    "hugepages"   # Memory config - no dependencies
    "network"     # Network config - no dependencies
    "ptp"         # Time sync - after network
    "evt"         # EVT cameras - after network
)

#######################################
# Display usage information
#######################################
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Pulse cluster node deployment orchestrator.

Options:
    --module MODULE     Run only the specified module
    --list              List available modules
    --help              Show this help message

Environment Variables:
    DRY_RUN=1           Preview changes without applying
    DEPLOY_DEBUG=1      Enable verbose debug output
    FAIL_FAST=false     Continue on module errors

Available Modules:
    hugepages   Configure huge pages for RDMA/Rivermax
    network     Configure EVT camera network
    ptp         Install and configure PTP time sync
    evt         Configure EVT camera routes

Examples:
    ./setup.sh                      # Full deployment
    DRY_RUN=1 ./setup.sh            # Preview all changes
    ./setup.sh --module ptp         # Install PTP only
    DEPLOY_DEBUG=1 ./setup.sh       # Verbose output

EOF
}

#######################################
# List available modules
#######################################
list_modules() {
    info "Available modules:"
    for module in "${MODULES[@]}"; do
        local install_script="$REPO_ROOT/modules/$module/install.sh"
        if [[ -x "$install_script" ]]; then
            echo "  - $module"
        else
            echo "  - $module (not found)"
        fi
    done
}

#######################################
# Run a single module
# Arguments:
#   module_name: Name of the module to run
# Returns:
#   0 on success, 1 on error, 2 if already configured
#######################################
run_module() {
    local module="$1"
    local install_script="$REPO_ROOT/modules/$module/install.sh"

    if [[ ! -x "$install_script" ]]; then
        err "Module not found or not executable: $module"
        return 1
    fi

    debug "Running module: $module"
    "$install_script"
}

#######################################
# Run pre-flight checks
#######################################
preflight() {
    debug "Running pre-flight checks"

    # Check we're on a supported distro
    local distro
    distro=$(get_distro)
    case "$distro" in
        ubuntu|debian)
            debug "Detected distro: $distro"
            ;;
        *)
            warn "Untested distribution: $distro"
            warn "This script is designed for Ubuntu/Debian"
            ;;
    esac

    # Check not in container (we need real kernel access)
    if is_container; then
        fatal "This script must run on bare metal, not in a container"
    fi

    # Basic commands
    local required_cmds=(nmcli ethtool git make)
    for cmd in "${required_cmds[@]}"; do
        if ! command_exists "$cmd"; then
            warn "Missing command: $cmd (will try to install)"
        fi
    done
}

#######################################
# Main entry point
#######################################
main() {
    local single_module=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --module)
                single_module="$2"
                shift 2
                ;;
            --list)
                list_modules
                exit 0
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                err "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    info "=== Pulse Node Deployment ==="

    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        warn "DRY-RUN MODE - No changes will be made"
    fi

    preflight

    # Single module mode
    if [[ -n "$single_module" ]]; then
        info "Running single module: $single_module"
        run_module "$single_module"
        exit $?
    fi

    # Full deployment
    local failed=0
    local skipped=0

    for module in "${MODULES[@]}"; do
        info "--- Module: $module ---"

        local exit_code=0
        run_module "$module" || exit_code=$?

        case $exit_code in
            0)
                debug "Module $module completed successfully"
                ;;
            2)
                debug "Module $module already configured"
                ((skipped++))
                ;;
            *)
                err "Module $module failed with exit code $exit_code"
                ((failed++))
                if [[ "${FAIL_FAST:-true}" == "true" ]]; then
                    fatal "Stopping due to module failure (set FAIL_FAST=false to continue)"
                fi
                ;;
        esac
    done

    echo ""
    info "=== Deployment Summary ==="
    info "Modules run: ${#MODULES[@]}"
    info "Skipped (already configured): $skipped"
    info "Failed: $failed"

    if [[ $failed -gt 0 ]]; then
        fatal "Deployment completed with $failed error(s)"
    fi

    info "=== Deployment Complete ==="

    # Post-deployment hints
    echo ""
    info "Next steps:"
    info "  Start PTP: sudo systemctl start ptp4l"
    info "  Monitor PTP: sudo journalctl -u ptp4l -f"
    info "  Configure cameras to ${EVT_CAMERA_SUBNET} via eCapture or optik"
}

main "$@"
