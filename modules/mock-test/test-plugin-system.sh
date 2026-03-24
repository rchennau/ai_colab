#!/usr/bin/env bash
# Plugin System Verification Test Suite
# Tests Phase 4: Verification & Testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Go up two levels from modules/mock-test to project root
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

test_skip() {
    echo -e "  ${YELLOW}○ SKIP:${NC} $1"
}

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Plugin System Verification Tests     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

# ============================================
# Test 1: Module Discovery
# ============================================
test_start "Module Discovery"

cd "$PROJECT_ROOT"

# Test with mock module enabled
export ENABLE_MOCK_TEST=true
MODULE_LIST=$(./scripts/module-manager.sh list 2>/dev/null)

if echo "$MODULE_LIST" | grep -q "mock-test"; then
    test_pass "Mock module discovered in list"
else
    test_fail "Mock module not found in list"
fi

if echo "$MODULE_LIST" | grep -q "✓ mock-test (active)"; then
    test_pass "Mock module shown as active"
else
    test_fail "Mock module not shown as active"
fi

# Test with mock module disabled
unset ENABLE_MOCK_TEST
MODULE_LIST=$(./scripts/module-manager.sh list 2>/dev/null)

if echo "$MODULE_LIST" | grep -q "mock-test"; then
    if echo "$MODULE_LIST" | grep -q "○ mock-test"; then
        test_pass "Mock module shown as inactive when disabled"
    else
        test_fail "Mock module status incorrect when disabled"
    fi
else
    test_pass "Mock module not shown when disabled (optional behavior)"
fi

# ============================================
# Test 2: Command Discovery
# ============================================
test_start "Command Discovery"

export ENABLE_MOCK_TEST=true
COMMANDS=$(./scripts/module-manager.sh commands all 2>/dev/null)

if echo "$COMMANDS" | grep -q "!mock-hello"; then
    test_pass "!mock-hello command discovered"
else
    test_fail "!mock-hello command not found"
fi

if echo "$COMMANDS" | grep -q "!mock-status"; then
    test_pass "!mock-status command discovered"
else
    test_fail "!mock-status command not found"
fi

if echo "$COMMANDS" | grep -q "(mock-test)"; then
    test_pass "Commands include module ID"
else
    test_fail "Commands missing module ID"
fi

# Test disabled module
unset ENABLE_MOCK_TEST
COMMANDS=$(./scripts/module-manager.sh commands all 2>/dev/null)

if [[ -z "$COMMANDS" ]] || ! echo "$COMMANDS" | grep -q "mock-"; then
    test_pass "Commands hidden when module disabled"
else
    test_fail "Commands visible when module disabled"
fi

# ============================================
# Test 3: Environment Variables
# ============================================
test_start "Environment Variable Parsing"

ENV_OUTPUT=$(./scripts/module-manager.sh env mock-test 2>/dev/null)

if echo "$ENV_OUTPUT" | grep -q "ENABLE_MOCK_TEST=true"; then
    test_pass "ENABLE_MOCK_TEST exported correctly"
else
    test_fail "ENABLE_MOCK_TEST not exported"
fi

if echo "$ENV_OUTPUT" | grep -q "MOCK_TEST_VALUE=test_123"; then
    test_pass "MOCK_TEST_VALUE exported correctly"
else
    test_fail "MOCK_TEST_VALUE not exported"
fi

# ============================================
# Test 4: Command Execution
# ============================================
test_start "Command Execution"

export ENABLE_MOCK_TEST=true
MOCK_OUTPUT=$(bash "$PROJECT_ROOT/modules/mock-test/scripts/mock-hello.sh" 2>&1)

if echo "$MOCK_OUTPUT" | grep -q "Mock Module: Hello World"; then
    test_pass "mock-hello.sh executes correctly"
else
    test_fail "mock-hello.sh execution failed"
fi

MOCK_STATUS=$(bash "$PROJECT_ROOT/modules/mock-test/scripts/mock-status.sh" 2>&1)

if echo "$MOCK_STATUS" | grep -q "Mock Module Status Report"; then
    test_pass "mock-status.sh executes correctly"
else
    test_fail "mock-status.sh execution failed"
fi

# ============================================
# Test 5: Dashboard Sections
# ============================================
test_start "Dashboard Section Parsing"

SECTIONS=$(./scripts/module-manager.sh dashboard mock-test 2>/dev/null)

if echo "$SECTIONS" | grep -q "Mock Test Status"; then
    test_pass "Dashboard section name parsed"
else
    test_fail "Dashboard section name not found"
fi

if echo "$SECTIONS" | grep -q "text"; then
    test_pass "Dashboard section type parsed"
else
    test_fail "Dashboard section type not found"
fi

if echo "$SECTIONS" | grep -q "modules/mock-test/status.txt"; then
    test_pass "Dashboard section source parsed"
else
    test_fail "Dashboard section source not found"
fi

# ============================================
# Test 6: Module Metadata
# ============================================
test_start "Module Metadata Parsing"

INFO=$(./scripts/module-manager.sh info mock-test 2>/dev/null)

if echo "$INFO" | grep -q "id=mock-test"; then
    test_pass "Module ID parsed"
else
    test_fail "Module ID not found"
fi

if echo "$INFO" | grep -q "name=Mock Test Module"; then
    test_pass "Module name parsed"
else
    test_fail "Module name not found"
fi

if echo "$INFO" | grep -q "version=1.0.0"; then
    test_pass "Module version parsed"
else
    test_fail "Module version not found"
fi

# ============================================
# Test 7: Enable/Disable Toggle
# ============================================
test_start "Enable/Disable Toggle (No Side Effects)"

# Enable
export ENABLE_MOCK_TEST=true
COMMANDS_ENABLED=$(./scripts/module-manager.sh commands all 2>/dev/null | wc -l)

# Disable
unset ENABLE_MOCK_TEST
COMMANDS_DISABLED=$(./scripts/module-manager.sh commands all 2>/dev/null | wc -l)

if [[ "$COMMANDS_ENABLED" -gt "$COMMANDS_DISABLED" ]]; then
    test_pass "Commands appear when enabled"
else
    test_fail "Commands don't appear when enabled"
fi

if [[ "$COMMANDS_DISABLED" -eq 0 ]] || [[ "$COMMANDS_DISABLED" -lt "$COMMANDS_ENABLED" ]]; then
    test_pass "Commands disappear when disabled"
else
    test_fail "Commands persist when disabled"
fi

# Test no side effects on other modules
export ENABLE_ATARI_LX=false
export ENABLE_MOCK_TEST=true
OTHER_MODULES=$(./scripts/module-manager.sh list 2>/dev/null | grep -c "atari-lx" || echo "0")

if [[ "$OTHER_MODULES" -eq 1 ]]; then
    test_pass "Other modules unaffected by mock module toggle"
else
    test_skip "Atari-LX module not available for testing"
fi

# ============================================
# Test 8: !help Command Simulation
# ============================================
test_start "!help Command Integration"

export ENABLE_MOCK_TEST=true
HELP_OUTPUT=$(./scripts/module-manager.sh commands all 2>/dev/null | grep -v "^Conductor\|^$" | cut -d'→' -f1 | tr '\n' ', ')

if echo "$HELP_OUTPUT" | grep -q "!mock-hello"; then
    test_pass "!mock-hello would appear in !help"
else
    test_fail "!mock-hello missing from !help output"
fi

if echo "$HELP_OUTPUT" | grep -q "!mock-status"; then
    test_pass "!mock-status would appear in !help"
else
    test_fail "!mock-status missing from !help output"
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
    echo -e "\n${GREEN}✓ All tests passed! Plugin system verified.${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed. Review output above.${NC}"
    exit 1
fi
