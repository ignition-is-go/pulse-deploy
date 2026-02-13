#!/bin/bash
set -e

# Sync Plastic SCM (Unity Version Control) workspace
# Usage: ./plastic-sync.sh
#        PLASTIC_WORKSPACE=/path/to/workspace ./plastic-sync.sh
#        PLASTIC_TOKEN=xxx PLASTIC_WORKSPACE=/path ./plastic-sync.sh

# --- Configuration ---

PLASTIC_SERVER="${PLASTIC_SERVER:-cloud}"
PLASTIC_TOKEN="${PLASTIC_TOKEN:-}"
PLASTIC_WORKSPACE="${PLASTIC_WORKSPACE:-}"
PLASTIC_REPO="${PLASTIC_REPO:-}"
PLASTIC_BRANCH="${PLASTIC_BRANCH:-/main}"

# --- Logging ---

info() {
    echo "[INFO] $*"
}

warn() {
    echo "[WARN] $*" >&2
}

fatal() {
    echo "[ERROR] $*" >&2
    exit 1
}

# --- Functions ---

check_cm() {
    if ! command -v cm >/dev/null 2>&1; then
        fatal "Plastic SCM CLI (cm) not found. Install Unity Version Control first."
    fi
    info "Found cm: $(command -v cm)"
}

configure_profile() {
    if [ -z "$PLASTIC_TOKEN" ]; then
        info "No token provided, using existing profile"
        return 0
    fi

    info "Configuring Plastic SCM profile with token"

    # Create/update profile with token auth
    if cm profile list 2>/dev/null | grep -q "$PLASTIC_SERVER"; then
        info "Updating existing profile for $PLASTIC_SERVER"
        cm profile delete "$PLASTIC_SERVER" 2>/dev/null || true
    fi

    cm profile create "$PLASTIC_SERVER" --token="$PLASTIC_TOKEN" || \
        fatal "Failed to create profile with token"

    info "Profile configured for $PLASTIC_SERVER"
}

verify_workspace() {
    if [ -z "$PLASTIC_WORKSPACE" ]; then
        fatal "PLASTIC_WORKSPACE not set"
    fi

    if [ ! -d "$PLASTIC_WORKSPACE" ]; then
        if [ -n "$PLASTIC_REPO" ]; then
            info "Workspace not found, will clone"
            return 1
        else
            fatal "Workspace $PLASTIC_WORKSPACE not found and PLASTIC_REPO not set for cloning"
        fi
    fi

    # Verify it's a plastic workspace
    if [ ! -d "$PLASTIC_WORKSPACE/.plastic" ]; then
        if [ -n "$PLASTIC_REPO" ]; then
            info "Directory exists but not a workspace, will initialize"
            return 1
        else
            fatal "$PLASTIC_WORKSPACE is not a Plastic workspace"
        fi
    fi

    return 0
}

clone_repo() {
    info "Cloning repository: $PLASTIC_REPO"

    local parent_dir
    parent_dir=$(dirname "$PLASTIC_WORKSPACE")
    mkdir -p "$parent_dir"

    local repo_spec="$PLASTIC_REPO"
    if [ -n "$PLASTIC_SERVER" ]; then
        repo_spec="$PLASTIC_REPO@$PLASTIC_SERVER"
    fi

    cm clone "$repo_spec" "$PLASTIC_WORKSPACE"
    info "Clone complete"
}

check_connection() {
    info "Checking server connection"

    cd "$PLASTIC_WORKSPACE"

    if ! cm checkconnection 2>/dev/null; then
        warn "Connection check failed, proceeding anyway"
    fi
}

get_workspace_info() {
    cd "$PLASTIC_WORKSPACE"

    info "Workspace: $PLASTIC_WORKSPACE"

    local ws_info
    ws_info=$(cm getworkspaceinfo 2>/dev/null || echo "unknown")
    info "Workspace info: $ws_info"

    local current_branch
    current_branch=$(cm status --header 2>/dev/null | grep -oP 'cs:\d+@br:\K[^ ]+' || echo "unknown")
    info "Current branch: $current_branch"
}

switch_branch() {
    if [ "$PLASTIC_BRANCH" = "/main" ]; then
        return 0
    fi

    cd "$PLASTIC_WORKSPACE"

    info "Switching to branch: $PLASTIC_BRANCH"
    cm switch "$PLASTIC_BRANCH" || warn "Branch switch failed, staying on current branch"
}

check_status() {
    cd "$PLASTIC_WORKSPACE"

    local status
    status=$(cm status --short 2>/dev/null || true)

    if [ -n "$status" ]; then
        warn "Workspace has local changes:"
        echo "$status"
        warn "Update may fail or overwrite changes"
    fi
}

do_update() {
    cd "$PLASTIC_WORKSPACE"

    info "Updating workspace"

    if cm update --last; then
        info "Update successful"
    else
        fatal "Update failed"
    fi
}

get_current_changeset() {
    cd "$PLASTIC_WORKSPACE"

    local cs
    cs=$(cm status --header 2>/dev/null | grep -oP 'cs:\K\d+' || echo "unknown")
    info "Current changeset: $cs"
}

# --- Main ---

do_sync() {
    info "=== Plastic SCM Sync ==="

    check_cm
    configure_profile

    if ! verify_workspace; then
        clone_repo
    fi

    check_connection
    get_workspace_info
    switch_branch
    check_status
    do_update
    get_current_changeset

    info "=== Sync Complete ==="
}

do_sync
