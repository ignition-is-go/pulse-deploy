#!/usr/bin/env bats
# tests/test_lib_common.bats - Tests for lib/common.sh
#
# Run with: bats tests/

setup() {
    export REPO_ROOT="${BATS_TEST_DIRNAME}/.."
    source "$REPO_ROOT/lib/common.sh"
}

@test "info logs message" {
    run info "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"INFO"* ]]
    [[ "$output" == *"test message"* ]]
}

@test "warn logs to stderr" {
    run warn "warning message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN"* ]]
}

@test "command_exists detects existing command" {
    run command_exists bash
    [ "$status" -eq 0 ]
}

@test "command_exists fails for nonexistent command" {
    run command_exists nonexistent_command_xyz
    [ "$status" -eq 1 ]
}

@test "validate_ip accepts valid IP" {
    source "$REPO_ROOT/lib/validation.sh"
    run validate_ip "192.168.1.1"
    [ "$status" -eq 0 ]
}

@test "validate_ip rejects invalid IP" {
    source "$REPO_ROOT/lib/validation.sh"
    run validate_ip "999.999.999.999"
    [ "$status" -eq 1 ]
}

@test "validate_cidr accepts valid CIDR" {
    source "$REPO_ROOT/lib/validation.sh"
    run validate_cidr "10.0.0.0/24"
    [ "$status" -eq 0 ]
}

@test "validate_cidr rejects invalid CIDR" {
    source "$REPO_ROOT/lib/validation.sh"
    run validate_cidr "10.0.0.0/33"
    [ "$status" -eq 1 ]
}

@test "get_distro returns distribution" {
    run get_distro
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}
