#!/usr/bin/env bash
# Test Suite: Enhanced Console (P17.3)
# Tests: readline console script, command history, tab completion, help

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

test_console_script_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Enhanced console script exists"

    local console_script="$PROJECT_ROOT/scripts/console.py"

    assert_file_exists "$console_script" "Console script exists"
    assert_executable "$console_script" "Console script is executable"
}

test_console_has_readline_support() {
    echo -e "\n${CYAN}▶${NC} Test: Console uses readline for history"

    local console_script="$PROJECT_ROOT/scripts/console.py"

    if grep -q "readline\|rlcompleter\|cmd" "$console_script" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Console uses readline/cmd module"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Console should use readline for history"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_console_has_command_completion() {
    echo -e "\n${CYAN}▶${NC} Test: Console has tab completion"

    local console_script="$PROJECT_ROOT/scripts/console.py"

    if grep -q "completedefault\|complete_\|tab.*complet" "$console_script" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Console has tab completion"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Console should have tab completion"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_console_has_help_system() {
    echo -e "\n${CYAN}▶${NC} Test: Console has help system"

    local console_script="$PROJECT_ROOT/scripts/console.py"

    if grep -q "do_help\|help_\|!help" "$console_script" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Console has help system"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Console should have help system"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_console_has_command_history() {
    echo -e "\n${CYAN}▶${NC} Test: Console has command history"

    local console_script="$PROJECT_ROOT/scripts/console.py"

    if grep -q "history\|HISTFILE\|readline.write_history" "$console_script" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Console has command history"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Console should have command history"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_console_handles_conductor_commands() {
    echo -e "\n${CYAN}▶${NC} Test: Console handles conductor commands"

    local console_script="$PROJECT_ROOT/scripts/console.py"

    local commands=("!status" "!test" "!build" "!help" "!kb")
    local found=0

    for cmd in "${commands[@]}"; do
        if grep -q "$cmd" "$console_script" 2>/dev/null; then
            ((found++))
        fi
    done

    if [[ $found -ge 3 ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Console handles $found/5 conductor commands"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Console should handle conductor commands (found $found/5)"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_dashboard_uses_enhanced_console() {
    echo -e "\n${CYAN}▶${NC} Test: Dashboard launcher uses enhanced console"

    if grep -q "console.py" "$PROJECT_ROOT/scripts/dashboard-launch.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Dashboard launcher references console.py"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Dashboard launcher should use console.py"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Enhanced Console Test Suite (P17.3)                ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_console_script_exists
    test_console_has_readline_support
    test_console_has_command_completion
    test_console_has_help_system
    test_console_has_command_history
    test_console_handles_conductor_commands
    test_dashboard_uses_enhanced_console

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
