#!/usr/bin/env bash
# Test Suite: Conductor Self-Monitoring (Phase 25)
# Tests: heartbeat, watchdog, state recovery

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

assert_valid_json() {
    local json="$1"
    local message="$2"

    if echo "$json" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message - invalid JSON"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Tests
# ============================================================

test_watchdog_file_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Watchdog script exists"

    assert_file_exists "$PROJECT_ROOT/scripts/conductor-watchdog.sh" "Watchdog script exists"
    assert_executable "$PROJECT_ROOT/scripts/conductor-watchdog.sh" "Watchdog script is executable"
}

test_watchdog_syntax() {
    echo -e "\n${CYAN}▶${NC} Test: Watchdog syntax is valid"

    if bash -n "$PROJECT_ROOT/scripts/conductor-watchdog.sh" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Watchdog syntax is valid"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Watchdog syntax error"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_conductor_has_heartbeat_logic() {
    echo -e "\n${CYAN}▶${NC} Test: Conductor has heartbeat logic"

    if grep -q "conductor_heartbeat" "$PROJECT_ROOT/scripts/conductor-workflow.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Conductor has heartbeat logic"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Conductor should have heartbeat logic"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_conductor_has_state_recovery() {
    echo -e "\n${CYAN}▶${NC} Test: Conductor has state recovery logic"

    if grep -q "conductor_event_cursor" "$PROJECT_ROOT/scripts/conductor-workflow.sh" && \
       grep -q "Recovered event cursor" "$PROJECT_ROOT/scripts/conductor-workflow.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Conductor has state recovery logic"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Conductor should have state recovery logic"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_conductor_has_start_timestamp() {
    echo -e "\n${CYAN}▶${NC} Test: Conductor has start timestamp"

    if grep -q "CONDUCTOR_START_TS" "$PROJECT_ROOT/scripts/conductor-workflow.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Conductor has start timestamp"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Conductor should have start timestamp"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_watchdog_has_backoff() {
    echo -e "\n${CYAN}▶${NC} Test: Watchdog has exponential backoff"

    if grep -q "calc_backoff\|BACKOFF_BASE\|3 \*\*" "$PROJECT_ROOT/scripts/conductor-watchdog.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Watchdog has exponential backoff"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Watchdog should have exponential backoff"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_watchdog_has_max_restarts() {
    echo -e "\n${CYAN}▶${NC} Test: Watchdog has max restart limit"

    if grep -q "MAX_RESTARTS" "$PROJECT_ROOT/scripts/conductor-watchdog.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Watchdog has max restart limit"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Watchdog should have max restart limit"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_watchdog_has_heartbeat_check() {
    echo -e "\n${CYAN}▶${NC} Test: Watchdog checks conductor heartbeat"

    if grep -q "check_conductor_heartbeat\|conductor_heartbeat" "$PROJECT_ROOT/scripts/conductor-watchdog.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Watchdog checks conductor heartbeat"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Watchdog should check conductor heartbeat"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_watchdog_status_command() {
    echo -e "\n${CYAN}▶${NC} Test: Watchdog status command works"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/conductor-watchdog.sh" status 2>&1)

    if echo "$output" | grep -q "Conductor Watchdog Status"; then
        echo -e "${GREEN}✓ PASS:${NC} Watchdog status command works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Watchdog status command failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_watchdog_help_command() {
    echo -e "\n${CYAN}▶${NC} Test: Watchdog help command works"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/conductor-watchdog.sh" help 2>&1)

    if echo "$output" | grep -q "start\|stop\|status\|help"; then
        echo -e "${GREEN}✓ PASS:${NC} Watchdog help command works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Watchdog help command failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_conductor_saves_pid() {
    echo -e "\n${CYAN}▶${NC} Test: Conductor saves PID for watchdog"

    if grep -q "ai-colab-conductor.pid" "$PROJECT_ROOT/scripts/conductor-workflow.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Conductor saves PID for watchdog"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Conductor should save PID for watchdog"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_watchdog_config_file() {
    echo -e "\n${CYAN}▶${NC} Test: Watchdog config file exists or is referenced"

    if grep -q "watchdog-config\|WATCHDOG_" "$PROJECT_ROOT/scripts/conductor-watchdog.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Watchdog references config"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Watchdog should reference config"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Conductor Self-Monitoring Test Suite (Phase 25)    ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_watchdog_file_exists
    test_watchdog_syntax
    test_conductor_has_heartbeat_logic
    test_conductor_has_state_recovery
    test_conductor_has_start_timestamp
    test_watchdog_has_backoff
    test_watchdog_has_max_restarts
    test_watchdog_has_heartbeat_check
    test_watchdog_status_command
    test_watchdog_help_command
    test_conductor_saves_pid
    test_watchdog_config_file

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
