#!/usr/bin/env bash
# Test Suite: Dynamic tmux Layouts (P17.1)
# Tests: Layout selection logic, agent count detection, layout application

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

assert_gt() {
    local a="$1"
    local b="$2"
    local message="$3"

    if [[ "$a" -gt "$b" ]] 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        echo -e "  Expected $a > $b"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# Helper: get layout name for agent count
get_layout_for_agents() {
    local agent_count="$1"
    (
        export PROJECT_ROOT="$PROJECT_ROOT"
        source "$PROJECT_ROOT/scripts/utils.sh" >/dev/null 2>&1
        tmux_get_layout_name "$agent_count"
    ) 2>&1
}

# Helper: get layout description
get_layout_description() {
    local layout_name="$1"
    (
        export PROJECT_ROOT="$PROJECT_ROOT"
        source "$PROJECT_ROOT/scripts/utils.sh" >/dev/null 2>&1
        tmux_get_layout_description "$layout_name"
    ) 2>&1
}

# ============================================================
# Tests
# ============================================================

test_layout_functions_exist() {
    echo -e "\n${CYAN}▶${NC} Test: Dynamic layout functions exist"

    local functions=("tmux_get_layout_name" "tmux_get_layout_description" "tmux_apply_layout")
    local all_exist=true

    for func in "${functions[@]}"; do
        if grep -q "^$func()" "$PROJECT_ROOT/scripts/dashboard-launch.sh" || \
           grep -q "^$func()" "$PROJECT_ROOT/scripts/utils.sh"; then
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

test_layout_selection_two_agents() {
    echo -e "\n${CYAN}▶${NC} Test: 2 agents → side-by-side layout"

    local layout
    layout=$(get_layout_for_agents 2)

    assert_equals "side-by-side" "$layout" "2 agents selects side-by-side layout"
}

test_layout_selection_three_agents() {
    echo -e "\n${CYAN}▶${NC} Test: 3 agents → grid layout"

    local layout
    layout=$(get_layout_for_agents 3)

    assert_equals "grid" "$layout" "3 agents selects grid layout"
}

test_layout_selection_four_agents() {
    echo -e "\n${CYAN}▶${NC} Test: 4 agents → grid layout"

    local layout
    layout=$(get_layout_for_agents 4)

    assert_equals "grid" "$layout" "4 agents selects grid layout"
}

test_layout_selection_five_agents() {
    echo -e "\n${CYAN}▶${NC} Test: 5 agents → tabbed layout"

    local layout
    layout=$(get_layout_for_agents 5)

    assert_equals "tabbed" "$layout" "5 agents selects tabbed layout"
}

test_layout_selection_eight_agents() {
    echo -e "\n${CYAN}▶${NC} Test: 8 agents → compact layout"

    local layout
    layout=$(get_layout_for_agents 8)

    assert_equals "compact" "$layout" "8 agents selects compact layout"
}

test_layout_selection_ten_agents() {
    echo -e "\n${CYAN}▶${NC} Test: 10 agents → compact layout"

    local layout
    layout=$(get_layout_for_agents 10)

    assert_equals "compact" "$layout" "10 agents selects compact layout"
}

test_layout_descriptions_exist() {
    echo -e "\n${CYAN}▶${NC} Test: Layout descriptions exist for all layouts"

    local layouts=("side-by-side" "grid" "tabbed" "compact")

    for layout in "${layouts[@]}"; do
        local desc
        desc=$(get_layout_description "$layout")

        if [[ -n "$desc" && "$desc" != *"not found"* ]]; then
            echo -e "${GREEN}✓ PASS:${NC} Description exists for '$layout': $desc"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL:${NC} Description missing for '$layout'"
            ((TESTS_FAILED++))
        fi
        ((TESTS_RUN++))
    done
}

test_layout_thresholds_monotonic() {
    echo -e "\n${CYAN}▶${NC} Test: Layout thresholds are monotonically increasing"

    # Verify layout progression makes sense
    local layout_1 layout_2 layout_3 layout_4 layout_5 layout_8
    layout_1=$(get_layout_for_agents 1)
    layout_2=$(get_layout_for_agents 2)
    layout_3=$(get_layout_for_agents 3)
    layout_5=$(get_layout_for_agents 5)
    layout_8=$(get_layout_for_agents 8)

    # 1-2 agents should use simpler layouts than 5+
    if [[ "$layout_1" == "side-by-side" || "$layout_2" == "side-by-side" ]] && \
       [[ "$layout_5" == "tabbed" ]] && [[ "$layout_8" == "compact" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Layout progression is correct"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Layout progression incorrect: 1=$layout_1, 2=$layout_2, 5=$layout_5, 8=$layout_8"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_conductor_uses_dynamic_layouts() {
    echo -e "\n${CYAN}▶${NC} Test: Dashboard launcher uses dynamic layout functions"

    if grep -q "tmux_get_layout_name\|tmux_apply_layout" "$PROJECT_ROOT/scripts/dashboard-launch.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Dashboard launcher uses dynamic layout functions"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Dashboard launcher should use dynamic layout functions"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Dynamic tmux Layouts Test Suite (P17.1)            ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_layout_functions_exist
    test_layout_selection_two_agents
    test_layout_selection_three_agents
    test_layout_selection_four_agents
    test_layout_selection_five_agents
    test_layout_selection_eight_agents
    test_layout_selection_ten_agents
    test_layout_descriptions_exist
    test_layout_thresholds_monotonic
    test_conductor_uses_dynamic_layouts

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
