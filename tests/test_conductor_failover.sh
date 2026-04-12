#!/usr/bin/env bash
# Test Suite: Conductor Failover & Self-Healing (P5.5)
# Tests: health monitoring, auto-restart logic, agent promotion, state recovery

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================
# Test Helpers
# ============================================================

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        echo -e "  Expected: '$expected'"
        echo -e "  Actual:   '$actual'"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"

    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        echo -e "  Expected to contain: '$needle'"
        echo -e "  Actual: '$haystack'"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

assert_file_exists() {
    local file="$1"
    local message="$2"

    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        echo -e "  File not found: '$file'"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

assert_executable() {
    local file="$1"
    local message="$2"

    if [[ -x "$file" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        echo -e "  Not executable: '$file'"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Tests
# ============================================================

test_failover_files_exist() {
    echo -e "\n${CYAN}▶${NC} Test: Failover files exist"

    assert_file_exists "$PROJECT_ROOT/scripts/conductor-failover.sh" "Conductor failover script exists"
}

test_failover_scripts_executable() {
    echo -e "\n${CYAN}▶${NC} Test: Failover scripts are executable"

    assert_executable "$PROJECT_ROOT/scripts/conductor-failover.sh" "Failover script is executable"
}

test_failover_syntax() {
    echo -e "\n${CYAN}▶${NC} Test: Failover script syntax is valid"

    if bash -n "$PROJECT_ROOT/scripts/conductor-failover.sh" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Bash syntax is valid"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Bash syntax error"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_failover_help() {
    echo -e "\n${CYAN}▶${NC} Test: Failover help works"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/conductor-failover.sh" help 2>&1)

    if echo "$output" | grep -q "monitor\|check\|restart\|promote\|status"; then
        echo -e "${GREEN}✓ PASS:${NC} Failover help works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Failover help does not work"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_failover_status() {
    echo -e "\n${CYAN}▶${NC} Test: Failover status command"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/conductor-failover.sh" status 2>&1)

    if echo "$output" | grep -q "Conductor Health\|Restart Count\|Failover State"; then
        echo -e "${GREEN}✓ PASS:${NC} Failover status works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Failover status does not work"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_health_check_functions() {
    echo -e "\n${CYAN}▶${NC} Test: Health check functions exist"

    if grep -q "check_conductor_health()" "$PROJECT_ROOT/scripts/conductor-failover.sh" && \
       grep -q "restart_conductor()" "$PROJECT_ROOT/scripts/conductor-failover.sh" && \
       grep -q "promote_agent()" "$PROJECT_ROOT/scripts/conductor-failover.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Health check functions exist"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Health check functions missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_restart_count_functions() {
    echo -e "\n${CYAN}▶${NC} Test: Restart count functions exist"

    if grep -q "get_restart_count()" "$PROJECT_ROOT/scripts/conductor-failover.sh" && \
       grep -q "increment_restart_count()" "$PROJECT_ROOT/scripts/conductor-failover.sh" && \
       grep -q "reset_restart_count()" "$PROJECT_ROOT/scripts/conductor-failover.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Restart count functions exist"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Restart count functions missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_monitor_loop_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Monitor loop exists"

    if grep -q "monitor_loop()" "$PROJECT_ROOT/scripts/conductor-failover.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Monitor loop exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Monitor loop missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_max_restart_configuration() {
    echo -e "\n${CYAN}▶${NC} Test: Max restart configuration exists"

    if grep -q "MAX_RESTARTS=" "$PROJECT_ROOT/scripts/conductor-failover.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Max restart configuration exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Max restart configuration missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Conductor Failover Test Suite (P5.5)               ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_failover_files_exist
    test_failover_scripts_executable
    test_failover_syntax
    test_failover_help
    test_failover_status
    test_health_check_functions
    test_restart_count_functions
    test_monitor_loop_exists
    test_max_restart_configuration

    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
