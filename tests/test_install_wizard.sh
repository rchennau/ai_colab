#!/usr/bin/env bash
# Integration Test Suite - Installation Wizard & CLI Experience
# Tests the interactive installer and reconfiguration modes

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_WIZARD="$PROJECT_ROOT/scripts/install-wizard.sh"
CONFIG_MGR="$PROJECT_ROOT/scripts/config-manager.sh"

# Test helpers
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

# ============================================
# Test Suite
# ============================================

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Phase 2 & 6 Test Suite               ║${NC}"
echo -e "${BLUE}║  Integration & CLI Wizard Experience  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

# Test 1: Wizard Script Exists
test_start "Wizard Script Exists"
if [[ -x "$INSTALL_WIZARD" ]]; then
    test_pass "install-wizard.sh is executable"
else
    test_fail "install-wizard.sh not found or not executable"
fi

# Test 2: Reconfigure Mode Access
test_start "Reconfigure Mode Entry"
# We'll use a mock input to see if it starts reconfigure mode
# Use -a with grep if available or just handle potential color codes
if bash "$INSTALL_WIZARD" --reconfigure << 'EOF' | tr -d '\000-\037' | grep -q "Reconfiguration Mode"; then
5
EOF
    test_pass "Reconfigure mode starts correctly"
else
    test_fail "Reconfigure mode failed to start"
fi

# Test 3: Install.sh Delegation
test_start "Install.sh Delegation"
if bash "$PROJECT_ROOT/install.sh" --help | tr -d '\000-\037' | grep -q -- "--wizard"; then
    test_pass "install.sh shows wizard options"
else
    test_fail "install.sh help missing wizard options"
fi

# Test 4: Profile Consistency
test_start "Profile Consistency"
# Check if profiles match schema via config-manager
for profile in minimal standard full; do
    if bash "$CONFIG_MGR" load-profile "$profile" >/dev/null 2>&1; then
        if bash "$CONFIG_MGR" validate >/dev/null 2>&1; then
            test_pass "Profile '$profile' is valid"
        else
            test_fail "Profile '$profile' failed validation"
        fi
    else
        test_fail "Failed to load profile '$profile'"
    fi
done

# Test 5: Legacy Preferences Sync
test_start "Legacy Preferences Sync"
# Run wizard apply mock (we need to be careful not to overwrite user config)
# We'll mock the config apply part or check if the function exists
if grep -q "save_legacy_prefs" "$INSTALL_WIZARD"; then
    test_pass "Legacy preference sync logic present"
else
    test_fail "Legacy preference sync logic missing"
fi

# Test 6: Python Environment Detection
test_start "Python Environment Detection"
if grep -q "detect_python_env" "$PROJECT_ROOT/install.sh"; then
    test_pass "Python environment detection function present"
else
    test_fail "Python environment detection function missing"
fi

# Test 7: Virtual Environment Setup
test_start "Virtual Environment Setup"
if grep -q "setup_venv_with_uv" "$PROJECT_ROOT/install.sh" && \
   grep -q "setup_venv_with_venv" "$PROJECT_ROOT/install.sh"; then
    test_pass "Virtual environment setup functions present"
else
    test_fail "Virtual environment setup functions missing"
fi

# Test 8: Python Command Variables
test_start "Python Command Variables"
if grep -q 'PYTHON_CMD=' "$PROJECT_ROOT/install.sh" && \
   grep -q 'PIP_CMD=' "$PROJECT_ROOT/install.sh"; then
    test_pass "Python command variables defined"
else
    test_fail "Python command variables missing"
fi

# Test 9: Virtual Environment in launch.sh
test_start "Virtual Environment Activation in Launcher"
if grep -q '.venv/bin/activate' "$PROJECT_ROOT/launch.sh"; then
    test_pass "Virtual environment activation in launch.sh"
else
    test_fail "Virtual environment activation missing in launch.sh"
fi

# ============================================
# Summary
# ============================================

echo -e "\n${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}Test Summary:${NC}"
echo -e "  ${GREEN}Passed:${NC}  $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC}  $TESTS_FAILED"
echo -e "${BLUE}════════════════════════════════════════${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}✓ All integration tests passed!${NC}"
    exit 0
else
    exit 1
fi
