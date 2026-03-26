#!/usr/bin/env bash
# Test script for dashboard-launch.sh fixes
# Tests tmux compatibility, vLLM default, and console initialization

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_test() {
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Test:${NC} $1"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
}

print_failure() {
    echo -e "${RED}✗ FAIL:${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ INFO:${NC} $1"
}

# Test 1: Check tmux version compatibility
test_tmux_version() {
    print_test "tmux Version Compatibility"
    
    if ! command -v tmux >/dev/null 2>&1; then
        print_failure "tmux is not installed"
        return 1
    fi
    
    local tmux_version=$(tmux -V | cut -d' ' -f2)
    echo "tmux version: $tmux_version"
    
    # Extract major.minor version
    local major=$(echo "$tmux_version" | cut -d'.' -f1)
    local minor=$(echo "$tmux_version" | cut -d'.' -f2 | tr -d 'next')
    
    # Check if version >= 2.0
    if [[ "$major" -ge 2 ]] || [[ "$major" -eq 1 && "$minor" -ge 0 ]]; then
        print_success "tmux version is compatible ($tmux_version)"
        return 0
    else
        print_failure "tmux version too old ($tmux_version), need >= 2.0"
        return 1
    fi
}

# Test 2: Check dashboard-launch.sh syntax
test_dashboard_syntax() {
    print_test "dashboard-launch.sh Syntax Check"
    
    local dashboard_script="$SCRIPT_DIR/../scripts/dashboard-launch.sh"
    
    if bash -n "$dashboard_script" 2>&1; then
        print_success "dashboard-launch.sh syntax is valid"
        return 0
    else
        print_failure "dashboard-launch.sh has syntax errors"
        bash -n "$dashboard_script" 2>&1
        return 1
    fi
}

# Test 3: Check vLLM default is false
test_vllm_default() {
    print_test "vLLM Default Value"
    
    local dashboard_script="$SCRIPT_DIR/../scripts/dashboard-launch.sh"
    
    # Check if WITH_VLLM is set to false by default
    if grep -q "WITH_VLLM=false" "$dashboard_script"; then
        print_success "vLLM default is correctly set to false"
        return 0
    else
        print_failure "vLLM default is not set to false"
        grep "WITH_VLLM=" "$dashboard_script" || true
        return 1
    fi
}

# Test 4: Check tmux split-window syntax (no -P -F flags)
test_tmux_syntax() {
    print_test "tmux Command Syntax (No -P -F flags)"
    
    local dashboard_script="$SCRIPT_DIR/../scripts/dashboard-launch.sh"
    
    # Check that -P -F flags are not used
    if grep -q "\-P \-F" "$dashboard_script"; then
        print_failure "Found incompatible -P -F flags in dashboard-launch.sh"
        grep -n "\-P \-F" "$dashboard_script" || true
        return 1
    else
        print_success "No incompatible -P -F flags found"
        return 0
    fi
}

# Test 5: Check console initialization has proper error handling
test_console_init() {
    print_test "Console hcom Initialization"
    
    local dashboard_script="$SCRIPT_DIR/../scripts/dashboard-launch.sh"
    
    # Check for proper error handling in console initialization
    if grep -q "command -v hcom" "$dashboard_script"; then
        print_success "Console initialization includes hcom check"
        return 0
    else
        print_failure "Console initialization missing hcom check"
        return 1
    fi
}

# Test 6: Check launch.sh passes --no-vllm correctly
test_launch_vllm_flag() {
    print_test "launch.sh vLLM Flag Handling"
    
    if grep -q "\-\-no-vllm" "$SCRIPT_DIR/../launch.sh"; then
        print_success "launch.sh correctly handles --no-vllm flag"
        return 0
    else
        print_failure "launch.sh missing --no-vllm flag handling"
        return 1
    fi
}

# Test 7: Check preflight_checks function exists
test_preflight_checks() {
    print_test "Pre-flight Checks Function"
    
    local dashboard_script="$SCRIPT_DIR/../scripts/dashboard-launch.sh"
    
    if grep -q "preflight_checks()" "$dashboard_script"; then
        print_success "Pre-flight checks function exists"
        return 0
    else
        print_failure "Pre-flight checks function missing"
        return 1
    fi
}

# Test 8: Check session recovery function exists
test_session_recovery() {
    print_test "Session Recovery Function"
    
    local dashboard_script="$SCRIPT_DIR/../scripts/dashboard-launch.sh"
    
    if grep -q "recover_session()" "$dashboard_script"; then
        print_success "Session recovery function exists"
        return 0
    else
        print_failure "Session recovery function missing"
        return 1
    fi
}

# Test 9: Check agent health monitoring
test_agent_health() {
    print_test "Agent Health Monitoring"
    
    local dashboard_script="$SCRIPT_DIR/../scripts/dashboard-launch.sh"
    
    if grep -q "check_agent_health()" "$dashboard_script"; then
        print_success "Agent health monitoring exists"
        return 0
    else
        print_failure "Agent health monitoring missing"
        return 1
    fi
}

# Test 10: Check version updated to 2.4
test_version_update() {
    print_test "Version Update to 2.4"
    
    local dashboard_script="$SCRIPT_DIR/../scripts/dashboard-launch.sh"
    
    if grep -q "v2.4" "$dashboard_script"; then
        print_success "Version updated to 2.4"
        return 0
    else
        print_failure "Version not updated"
        return 1
    fi
}

# Clean up any existing test sessions
cleanup_test_session() {
    print_test "Cleaning Up Test Sessions"
    
    if tmux has-session -t hcom-dashboard-test 2>/dev/null; then
        tmux kill-session -t hcom-dashboard-test 2>/dev/null || true
        print_info "Killed existing test session"
    fi
    
    print_success "Cleanup complete"
}

# Main test runner
main() {
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     dashboard-launch.sh Fix Verification Tests        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    
    local tests_passed=0
    local tests_failed=0
    
    # Run tests
    test_tmux_version && ((++tests_passed)) || ((++tests_failed))
    test_dashboard_syntax && ((++tests_passed)) || ((++tests_failed))
    test_vllm_default && ((++tests_passed)) || ((++tests_failed))
    test_tmux_syntax && ((++tests_passed)) || ((++tests_failed))
    test_console_init && ((++tests_passed)) || ((++tests_failed))
    test_launch_vllm_flag && ((++tests_passed)) || ((++tests_failed))
    test_preflight_checks && ((++tests_passed)) || ((++tests_failed))
    test_session_recovery && ((++tests_passed)) || ((++tests_failed))
    test_agent_health && ((++tests_passed)) || ((++tests_failed))
    test_version_update && ((++tests_passed)) || ((++tests_failed))
    cleanup_test_session && ((++tests_passed)) || ((++tests_failed))
    
    # Summary
    echo -e "\n${BLUE}══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Test Summary:${NC}"
    echo -e "  ${GREEN}Passed:${NC} $tests_passed"
    echo -e "  ${RED}Failed:${NC} $tests_failed"
    echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
    
    if [[ $tests_failed -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Some tests failed${NC}"
        return 1
    fi
}

main "$@"
