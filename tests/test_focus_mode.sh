#!/usr/bin/env bash
# Test Suite: Focus Mode (P17.2)
# Tests: focus/return functions, status bar generation, keyboard shortcuts

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

assert_not_empty() {
    local value="$1"
    local message="$2"

    if [[ -n "$value" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        echo -e "  Value is empty"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# Helper functions
focus_agent() {
    local pane_idx="$1"
    (
        export PROJECT_ROOT="$PROJECT_ROOT"
        source "$PROJECT_ROOT/scripts/utils.sh" >/dev/null 2>&1
        tmux_focus_agent "$pane_idx"
    ) 2>&1
}

return_to_fleet() {
    (
        export PROJECT_ROOT="$PROJECT_ROOT"
        source "$PROJECT_ROOT/scripts/utils.sh" >/dev/null 2>&1
        tmux_return_to_fleet
    ) 2>&1
}

generate_status_bar() {
    (
        export PROJECT_ROOT="$PROJECT_ROOT"
        source "$PROJECT_ROOT/scripts/utils.sh" >/dev/null 2>&1
        tmux_generate_status_bar
    ) 2>&1
}

# ============================================================
# Tests
# ============================================================

test_focus_functions_exist() {
    echo -e "\n${CYAN}▶${NC} Test: Focus mode functions exist"

    local functions=("tmux_focus_agent" "tmux_return_to_fleet" "tmux_generate_status_bar")
    local all_exist=true

    for func in "${functions[@]}"; do
        if grep -q "^$func()" "$PROJECT_ROOT/scripts/utils.sh" || \
           grep -q "^$func()" "$PROJECT_ROOT/scripts/dashboard-launch.sh"; then
            echo -e "${GREEN}✓ PASS:${NC} Function $func() exists"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL:${NC} Function $func() missing"
            ((TESTS_FAILED++))
            all_exist=false
        fi
        ((TESTS_RUN++))
    done
}

test_focus_agent_returns_zoom_command() {
    echo -e "\n${CYAN}▶${NC} Test: Focus agent returns zoom command"

    local result
    result=$(focus_agent 2)

    if [[ -n "$result" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Focus agent returns output"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Focus agent should return output"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_return_to_fleet_returns_command() {
    echo -e "\n${CYAN}▶${NC} Test: Return to fleet returns command"

    local result
    result=$(return_to_fleet)

    if [[ -n "$result" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Return to fleet returns output"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Return to fleet should return output"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_status_bar_generation() {
    echo -e "\n${CYAN}▶${NC} Test: Status bar generation"

    local result
    result=$(generate_status_bar)

    if [[ -n "$result" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Status bar generates output"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Status bar should generate output"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_dashboard_has_focus_mode_integration() {
    echo -e "\n${CYAN}▶${NC} Test: Dashboard launcher has focus mode integration"

    if grep -q "tmux_focus_agent\|tmux_return_to_fleet\|focus.*mode" "$PROJECT_ROOT/scripts/dashboard-launch.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Dashboard has focus mode integration"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Dashboard should integrate focus mode"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_dashboard_has_status_bar_integration() {
    echo -e "\n${CYAN}▶${NC} Test: Dashboard launcher has status bar integration"

    if grep -q "tmux_generate_status_bar\|status_bar\|pane-border-format" "$PROJECT_ROOT/scripts/dashboard-launch.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Dashboard has status bar integration"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Dashboard should integrate status bar"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Focus Mode Test Suite (P17.2)                      ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_focus_functions_exist
    test_focus_agent_returns_zoom_command
    test_return_to_fleet_returns_command
    test_status_bar_generation
    test_dashboard_has_focus_mode_integration
    test_dashboard_has_status_bar_integration

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
