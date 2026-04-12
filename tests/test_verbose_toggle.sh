#!/usr/bin/env bash
# Test Suite: Dashboard Verbose Toggle (P6.4)
# Tests: verbose toggle, compact/verbose rendering, tmux key binding

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

test_verbose_toggle_file_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Verbose toggle script exists"

    assert_file_exists "$PROJECT_ROOT/scripts/verbose-toggle.sh" "Verbose toggle script exists"
    assert_executable "$PROJECT_ROOT/scripts/verbose-toggle.sh" "Verbose toggle script is executable"
}

test_verbose_toggle_syntax() {
    echo -e "\n${CYAN}▶${NC} Test: Verbose toggle syntax is valid"

    if bash -n "$PROJECT_ROOT/scripts/verbose-toggle.sh" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Bash syntax is valid"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Bash syntax error"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_verbose_toggle_status() {
    echo -e "\n${CYAN}▶${NC} Test: Verbose toggle status command works"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/verbose-toggle.sh" status 2>&1)

    if echo "$output" | grep -q "Dashboard mode:"; then
        echo -e "${GREEN}✓ PASS:${NC} Status command works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Status command failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_verbose_toggle_toggle() {
    echo -e "\n${CYAN}▶${NC} Test: Verbose toggle toggle command works"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/verbose-toggle.sh" toggle 2>&1)

    if echo "$output" | grep -q "Dashboard mode:"; then
        echo -e "${GREEN}✓ PASS:${NC} Toggle command works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Toggle command failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_verbose_toggle_set_compact() {
    echo -e "\n${CYAN}▶${NC} Test: Verbose toggle set compact works"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/verbose-toggle.sh" set compact 2>&1)

    if echo "$output" | grep -q "compact"; then
        echo -e "${GREEN}✓ PASS:${NC} Set compact works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Set compact failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_verbose_toggle_set_verbose() {
    echo -e "\n${CYAN}▶${NC} Test: Verbose toggle set verbose works"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/verbose-toggle.sh" set verbose 2>&1)

    if echo "$output" | grep -q "verbose"; then
        echo -e "${GREEN}✓ PASS:${NC} Set verbose works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Set verbose failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_dashboard_has_verbose_binding() {
    echo -e "\n${CYAN}▶${NC} Test: Dashboard has verbose toggle key binding"

    if grep -q "bind-key v" "$PROJECT_ROOT/scripts/dashboard-launch.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Dashboard has Ctrl+b v binding"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Dashboard missing Ctrl+b v binding"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_dashboard_uses_verbose_toggle() {
    echo -e "\n${CYAN}▶${NC} Test: Dashboard references verbose toggle"

    if grep -q "verbose-toggle.sh" "$PROJECT_ROOT/scripts/dashboard-launch.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Dashboard uses verbose-toggle.sh"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Dashboard should use verbose-toggle.sh"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_dashboard_checks_verbose_mode() {
    echo -e "\n${CYAN}▶${NC} Test: Dashboard checks verbose mode"

    if grep -q "dashboard_verbose_mode\|verbose_mode" "$PROJECT_ROOT/scripts/conductor-dashboard.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Dashboard checks verbose mode"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Dashboard should check verbose mode"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_dashboard_renders_compact() {
    echo -e "\n${CYAN}▶${NC} Test: Dashboard renders compact summaries"

    if grep -q "Compact Mode" "$PROJECT_ROOT/scripts/conductor-dashboard.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Dashboard renders compact mode"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Dashboard should render compact mode"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_dashboard_renders_verbose() {
    echo -e "\n${CYAN}▶${NC} Test: Dashboard renders verbose protocol messages"

    if grep -q "Verbose Mode" "$PROJECT_ROOT/scripts/conductor-dashboard.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Dashboard renders verbose mode"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Dashboard should render verbose mode"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_verbose_toggle_help() {
    echo -e "\n${CYAN}▶${NC} Test: Verbose toggle help works"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/verbose-toggle.sh" help 2>&1)

    if echo "$output" | grep -q "Usage\|toggle\|status\|set\|render"; then
        echo -e "${GREEN}✓ PASS:${NC} Help command works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Help command failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Dashboard Verbose Toggle Test Suite (P6.4)         ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_verbose_toggle_file_exists
    test_verbose_toggle_syntax
    test_verbose_toggle_status
    test_verbose_toggle_toggle
    test_verbose_toggle_set_compact
    test_verbose_toggle_set_verbose
    test_dashboard_has_verbose_binding
    test_dashboard_uses_verbose_toggle
    test_dashboard_checks_verbose_mode
    test_dashboard_renders_compact
    test_dashboard_renders_verbose
    test_verbose_toggle_help

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
