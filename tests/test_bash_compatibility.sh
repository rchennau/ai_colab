#!/usr/bin/env bash
# Regression Test: Bash 3.2 Compatibility
# Verifies that scripts do not use Bash 4.0+ features like associative arrays

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

test_start() {
    echo -e "\n${BLUE}TEST:${NC} $1"
}

test_pass() {
    echo -e "  ${GREEN}✓ PASS:${NC} $1"
}

test_fail() {
    echo -e "  ${RED}✗ FAIL:${NC} $1"
    exit 1
}

# ============================================
# Test Suite
# ============================================

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Bash Compatibility Test Suite         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

# Test 1: Check for 'declare -A' usage in all shell scripts
test_start "No 'declare -A' usage"
# Exclude this script and search for actual uncommented code usage
if grep -r "^[[:space:]]*declare -A" "$PROJECT_ROOT" --include="*.sh" | grep -v "tests/test_bash_compatibility.sh"; then
    test_fail "Found 'declare -A' which is incompatible with Bash 3.2 (macOS default)"
else
    test_pass "No 'declare -A' found in shell scripts"
fi

# Test 2: Syntax check with system bash (might be 3.2 on macOS)
test_start "Syntax check with system bash"
for script in "$PROJECT_ROOT"/*.sh "$PROJECT_ROOT/scripts"/*.sh; do
    if [[ -f "$script" ]]; then
        if bash -n "$script"; then
            test_pass "Syntax OK: $(basename "$script")"
        else
            test_fail "Syntax Error in $script"
        fi
    fi
done

# Test 3: Functional check of refactored API key logic in install-wizard.sh
test_start "API Key logic functional check"
# We'll source a subset of the script or run it in a way that tests the lookup functions
# Create a temporary test script that sources the wizard and calls the lookup functions
cat << 'EOF' > temp_test.sh
PROJECT_ROOT="."
SCRIPT_DIR="./scripts"
CONFIG_MGR="./scripts/config-manager.sh"
# Mock utils.sh if needed
mkdir -p scripts
touch scripts/utils.sh
# Source the wizard (we need to skip the main execution)
# To do this safely, we'll grep out the functions we want to test
sed -n '/get_api_key_desc() {/,/^}/p' scripts/install-wizard.sh > test_funcs.sh
sed -n '/get_auth_method() {/,/^}/p' scripts/install-wizard.sh >> test_funcs.sh
source test_funcs.sh

# Test get_api_key_desc
desc=$(get_api_key_desc "GEMINI_API_KEY")
if [[ "$desc" == *"Gemini"* ]]; then
    echo "SUCCESS: get_api_key_desc functional"
else
    echo "FAILURE: get_api_key_desc returned '$desc'"
    exit 1
fi

# Test get_auth_method
method=$(get_auth_method "GEMINI")
if [[ "$method" == "both" ]]; then
    echo "SUCCESS: get_auth_method functional"
else
    echo "FAILURE: get_auth_method returned '$method'"
    exit 1
fi
EOF

if bash temp_test.sh; then
    test_pass "Refactored lookup functions are functional"
else
    test_fail "Refactored lookup functions failed functional check"
fi
rm -f temp_test.sh test_funcs.sh

echo -e "\n${GREEN}✓ All Bash compatibility tests passed!${NC}"
