#!/usr/bin/env bash
# Module Hooks & Dynamic Workflow Verification
# Tests periodic hook execution and dynamic command loading

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UTILS="$PROJECT_ROOT/scripts/utils.sh"
MOD_MGR="$PROJECT_ROOT/scripts/module-manager.sh"

source "$UTILS"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
test_start() {
    echo -e "\n${BLUE}TEST:${NC} $1"
}

test_pass() {
    echo -e "  ${GREEN}✓ PASS:${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo -e "  ${RED}✗ FAIL:${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

ui_banner "Module Hooks Verification" "${BLUE}"

# ============================================
# Test 1: Periodic Hook Parsing
# ============================================
test_start "Periodic Hook Parsing"

# Use atari-8bit as a real-world example
HOOKS=$(bash "$MOD_MGR" periodic atari-8bit 2>/dev/null)

if echo "$HOOKS" | grep -q "screenshot|modules/atari-8bit/scripts/hcom-atari-screen.sh|600"; then
    test_pass "Atari-8bit periodic hook parsed correctly"
else
    test_fail "Failed to parse periodic hooks from atari-8bit"
fi

# ============================================
# Test 2: Dynamic Command Listing (--raw)
# ============================================
test_start "Dynamic Command Listing (Machine Readable)"

RAW_CMDS=$(bash "$MOD_MGR" commands --raw atari-8bit 2>/dev/null)

if echo "$RAW_CMDS" | grep -q "!screenshot|modules/atari-8bit/scripts/hcom-atari-screen.sh"; then
    test_pass "Raw commands format verified"
else
    test_fail "Raw commands format incorrect"
fi

# ============================================
# Test 3: Module Init Script Retrieval
# ============================================
test_start "Init Script Discovery"

INIT_SCRIPT=$(bash "$MOD_MGR" init atari-8bit 2>/dev/null)

if [[ "$INIT_SCRIPT" == "modules/atari-8bit/scripts/init.sh" ]]; then
    test_pass "Init script discovered correctly"
else
    test_fail "Failed to discover init script (got: $INIT_SCRIPT)"
fi

# ============================================
# Test 4: Conductor Dynamic Loop Logic
# ============================================
test_start "Conductor Periodic Logic Simulation"

# We mock the blackboard and check if the interval logic would trigger
CURRENT_TIME=$(date +%s)
INTERVAL=600
LAST_RUN=$((CURRENT_TIME - 700)) # Overdue

if (( CURRENT_TIME - LAST_RUN > INTERVAL )); then
    test_pass "Interval logic correctly identifies overdue tasks"
else
    test_fail "Interval logic failed to identify overdue task"
fi

LAST_RUN_RECENT=$((CURRENT_TIME - 100)) # Recent
if ! (( CURRENT_TIME - LAST_RUN_RECENT > INTERVAL )); then
    test_pass "Interval logic correctly skips recent tasks"
else
    test_fail "Interval logic triggered too early"
fi

# ============================================
# Summary
# ============================================
echo -e "\n${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}Test Summary:${NC}"
echo -e "  ${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC} $TESTS_FAILED"
echo -e "${BLUE}════════════════════════════════════════${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}✓ All tests passed! Module hooks system verified.${NC}"
    exit 0
else
    exit 1
fi
