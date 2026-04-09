#!/usr/bin/env bash
# Phase 1 Test Suite - Configuration Management Foundation
# Tests configuration schema, manager, and state tracking

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
TESTS_SKIPPED=0

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_MANAGER="$PROJECT_ROOT/scripts/config-manager.sh"

# Activate virtual environment if it exists
if [[ -f "$PROJECT_ROOT/.venv/bin/activate" ]]; then
    source "$PROJECT_ROOT/.venv/bin/activate"
fi

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

test_skip() {
    echo -e "  ${YELLOW}○ SKIP:${NC} $1"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

has_command() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================
# Test Suite
# ============================================

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Phase 1 Test Suite                   ║${NC}"
echo -e "${BLUE}║  Configuration Management Foundation  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

# Test 1: Config Manager Exists
test_start "Config Manager Script Exists"
if [[ -x "$CONFIG_MANAGER" ]]; then
    test_pass "config-manager.sh is executable"
else
    test_fail "config-manager.sh not found or not executable"
fi

# Test 2: Help Command
test_start "Help Command"
if "$CONFIG_MANAGER" help | grep -q "USAGE:"; then
    test_pass "Help command works"
else
    test_fail "Help command failed"
fi

# Test 3: Initialize State
test_start "Initialize State"
# Force re-init by deleting state
rm -f "$PROJECT_ROOT/.ai-colab-state.json"
if "$CONFIG_MANAGER" init 2>&1 | grep -q "State file initialized"; then
    test_pass "State initialization works"
else
    test_fail "State initialization failed"
fi

# Test 4: Set Configuration Value
test_start "Set Configuration Value"
if "$CONFIG_MANAGER" set test.key "test_value" 2>&1 | grep -q "Configuration updated"; then
    test_pass "Set configuration value"
else
    test_fail "Set configuration value failed"
fi

# Test 5: Get Configuration Value
test_start "Get Configuration Value"
value=$("$CONFIG_MANAGER" get test.key "default")
if [[ "$value" == "test_value" ]]; then
    test_pass "Get configuration value"
else
    test_fail "Get configuration value failed (got: $value)"
fi

# Test 6: List Configuration
test_start "List Configuration"
if "$CONFIG_MANAGER" list | grep -q "test.key"; then
    test_pass "List configuration"
else
    test_fail "List configuration failed"
fi

# Test 7: List Configuration as JSON
test_start "List Configuration as JSON"
if "$CONFIG_MANAGER" list --json | grep -q "{"; then
    test_pass "List configuration as JSON"
else
    test_fail "List configuration as JSON failed"
fi

# Test 8: Validate Configuration
test_start "Validate Configuration"
if "$CONFIG_MANAGER" validate 2>&1 | grep -q "validation passed\|Skipping validation"; then
    test_pass "Validate configuration"
else
    test_fail "Validate configuration failed"
fi

# Test 9: Create Backup
test_start "Create Backup"
if "$CONFIG_MANAGER" backup 2>&1 | grep -q "Backup created"; then
    test_pass "Create backup"
else
    test_fail "Create backup failed"
fi

# Test 10: State Update
test_start "State Update"
if "$CONFIG_MANAGER" state-set installation.status "in-progress" 2>&1; then
    test_pass "State update"
else
    test_fail "State update failed"
fi

# Test 11: Get State
test_start "Get State"
status=$("$CONFIG_MANAGER" state installation.status)
if [[ -n "$status" ]]; then
    test_pass "Get state value"
else
    test_fail "Get state value failed"
fi

# Test 12: Profile Listing
test_start "Profile Listing"
if "$CONFIG_MANAGER" profiles | grep -q "standard"; then
    test_pass "Profile listing"
else
    test_fail "Profile listing failed"
fi

# Test 13: Load Profile
test_start "Load Profile"
# First backup current config
cp "$PROJECT_ROOT/config/config.toml" "$PROJECT_ROOT/config/config.toml.test" 2>/dev/null || true
if "$CONFIG_MANAGER" load-profile minimal 2>&1 | grep -q "Loaded profile"; then
    test_pass "Load profile"
else
    test_fail "Load profile failed"
fi
# Restore original config
mv "$PROJECT_ROOT/config/config.toml.test" "$PROJECT_ROOT/config/config.toml" 2>/dev/null || true

# Test 14: Save Profile
test_start "Save Profile"
if "$CONFIG_MANAGER" save-profile test-profile 2>&1 | grep -q "Saved profile"; then
    test_pass "Save profile"
    # Clean up test profile
    rm -f "$PROJECT_ROOT/config/profiles/test-profile.toml"
else
    test_fail "Save profile failed"
fi

# Test 15: Export Configuration
test_start "Export Configuration"
if "$CONFIG_MANAGER" export /tmp/config-export.json 2>&1 | grep -q "exported"; then
    test_pass "Export configuration"
    # Clean up
    rm -f /tmp/config-export.json
else
    test_fail "Export configuration failed"
fi

# Test 16: Schema File Exists
test_start "Schema File Exists"
if [[ -f "$PROJECT_ROOT/config/config.schema.json" ]]; then
    test_pass "Schema file exists"
else
    test_fail "Schema file not found"
fi

# Test 17: Schema Validation (JSON Schema)
test_start "Schema Validation"
if has_command python3; then
    python3 -c "
import json
import sys

try:
    with open('$PROJECT_ROOT/config/config.schema.json', 'r') as f:
        schema = json.load(f)
    
    # Check key schema elements
    if 'properties' not in schema:
        print('Missing properties in schema', file=sys.stderr)
        sys.exit(1)

    if 'version' not in schema['properties']:
        print('Missing version definition', file=sys.stderr)
        sys.exit(1)

    if 'installation' not in schema['properties']:
        print('Missing installation definition', file=sys.stderr)
        sys.exit(1)

    print('Schema validation passed')
    sys.exit(0)

except Exception as e:
    print(f'Schema error: {e}', file=sys.stderr)
    sys.exit(1)
"
    if [[ $? -eq 0 ]]; then
        test_pass "Schema structure valid"
    else
        test_fail "Schema structure invalid"
    fi
else
    test_skip "Python3 not available"
fi

# Test 18: Profile Files Exist
test_start "Profile Files Exist"
profiles_ok=true
for profile in minimal standard full; do
    if [[ ! -f "$PROJECT_ROOT/config/profiles/${profile}.toml" ]]; then
        profiles_ok=false
        break
    fi
done

if [[ "$profiles_ok" == "true" ]]; then
    test_pass "All profile files exist"
else
    test_fail "Some profile files missing"
fi

# Test 19: State File Structure
test_start "State File Structure"
if [[ -f "$PROJECT_ROOT/.ai-colab-state.json" ]]; then
    if python3 -c "import json; json.load(open('$PROJECT_ROOT/.ai-colab-state.json'))" 2>/dev/null; then
        test_pass "State file is valid JSON"
    else
        test_fail "State file is not valid JSON"
    fi
else
    test_fail "State file not found"
fi

# Test 20: Backup Directory
test_start "Backup Directory"
if [[ -d "$PROJECT_ROOT/config/backups" ]]; then
    backup_count=$(ls -1 "$PROJECT_ROOT/config/backups"/config.*.toml 2>/dev/null | wc -l)
    if [[ $backup_count -gt 0 ]]; then
        test_pass "Backup directory with $backup_count backup(s)"
    else
        test_skip "Backup directory empty"
    fi
else
    test_fail "Backup directory not found"
fi

# ============================================
# Summary
# ============================================

echo -e "\n${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}Test Summary:${NC}"
echo -e "  ${GREEN}Passed:${NC}  $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC}  $TESTS_FAILED"
echo -e "  ${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
echo -e "${BLUE}════════════════════════════════════════${NC}"

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}✓ All tests passed! ($TESTS_PASSED/$TOTAL_TESTS)${NC}"
    echo -e "${GREEN}Phase 1: Configuration Management Foundation - COMPLETE${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed. ($TESTS_FAILED/$TOTAL_TESTS)${NC}"
    echo -e "${YELLOW}Phase 1: Configuration Management Foundation - INCOMPLETE${NC}"
    exit 1
fi
