#!/usr/bin/env bash
# Test Suite: Real-Time Fleet Status Bar (P17.4)
# Tests: status bar script, tmux status line updates, agent health display

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

test_status_bar_script_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Status bar update script exists"

    local status_script="$PROJECT_ROOT/scripts/update-status-bar.sh"

    assert_file_exists "$status_script" "Status bar script exists"
    assert_executable "$status_script" "Status bar script is executable"
}

test_status_bar_uses_heartbeat_data() {
    echo -e "\n${CYAN}▶${NC} Test: Status bar uses heartbeat data from blackboard"

    local status_script="$PROJECT_ROOT/scripts/update-status-bar.sh"

    if grep -q "fleet_health_\|blackboard_get\|hcom-kv" "$status_script" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Status bar uses heartbeat data"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Status bar should use heartbeat data"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_status_bar_updates_tmux_status_line() {
    echo -e "\n${CYAN}▶${NC} Test: Status bar updates tmux status line"

    local status_script="$PROJECT_ROOT/scripts/update-status-bar.sh"

    if grep -q "tmux.*status-left\|tmux.*set-option.*status" "$status_script" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Status bar updates tmux status line"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Status bar should update tmux status line"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_status_bar_has_update_interval() {
    echo -e "\n${CYAN}▶${NC} Test: Status bar has update interval (20s)"

    local status_script="$PROJECT_ROOT/scripts/update-status-bar.sh"

    if grep -q "sleep.*20\|INTERVAL.*20" "$status_script" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Status bar has 20s update interval"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Status bar should have 20s update interval"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_dashboard_starts_status_bar() {
    echo -e "\n${CYAN}▶${NC} Test: Dashboard launcher starts status bar updater"

    if grep -q "update-status-bar\|status.*bar.*update\|tmux.*status" "$PROJECT_ROOT/scripts/dashboard-launch.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Dashboard starts status bar updater"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Dashboard should start status bar updater"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_status_bar_shows_agent_states() {
    echo -e "\n${CYAN}▶${NC} Test: Status bar shows different agent states"

    local status_script="$PROJECT_ROOT/scripts/update-status-bar.sh"

    local states=("ready" "busy" "crashed" "unhealthy")
    local found=0

    for state in "${states[@]}"; do
        if grep -q "$state" "$status_script" 2>/dev/null; then
            ((found++))
        fi
    done

    if [[ $found -ge 3 ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Status bar handles $found/4 agent states"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Status bar should handle agent states (found $found/4)"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Real-Time Fleet Status Bar Test Suite (P17.4)      ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_status_bar_script_exists
    test_status_bar_uses_heartbeat_data
    test_status_bar_updates_tmux_status_line
    test_status_bar_has_update_interval
    test_dashboard_starts_status_bar
    test_status_bar_shows_agent_states

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
