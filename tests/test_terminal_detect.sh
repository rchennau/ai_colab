#!/usr/bin/env bash
# Terminal Detection Verification
# Tests detection of environment and terminal emulator

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UTILS="$PROJECT_ROOT/scripts/utils.sh"
TERM_TOOL="$PROJECT_ROOT/scripts/terminal-detect.sh"

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

ui_banner "Terminal Detection Verification" "${BLUE}"

# ============================================
# Test 1: Basic Detection
# ============================================
test_start "Core Detection Logic"

# Source the tool to get functions
source "$TERM_TOOL"

# Mock variables to simulate different environments
export TERM_PROGRAM="vscode"
detect_terminal > /dev/null

if [[ "$AI_COLAB_TERMINAL" == "vscode" ]]; then
    test_pass "Correctly detected VS Code terminal"
else
    test_fail "Failed to detect VS Code terminal (got: $AI_COLAB_TERMINAL)"
fi

# ============================================
# Test 2: tmux Config Selection
# ============================================
test_start "tmux Config Selection"

export AI_COLAB_TERMINAL="iterm2"
CONFIG=$(get_tmux_config)

if [[ "$CONFIG" == *"tmux.iterm2.conf" ]]; then
    test_pass "Selected correct config for iTerm2"
else
    test_fail "Incorrect config for iTerm2 (got: $CONFIG)"
fi

export AI_COLAB_TERMINAL="windows_terminal"
CONFIG=$(get_tmux_config)

if [[ "$CONFIG" == *"tmux.windows-terminal.conf" ]]; then
    test_pass "Selected correct config for Windows Terminal"
else
    test_fail "Incorrect config for Windows Terminal (got: $CONFIG)"
fi

# ============================================
# Test 3: Dynamic Width (from utils.sh)
# ============================================
test_start "Dynamic UI Width"

if [[ -n "$UI_WIDTH" ]] && [[ $UI_WIDTH -ge 80 ]] && [[ $UI_WIDTH -le 100 ]]; then
    test_pass "UI_WIDTH initialized within safety bounds ($UI_WIDTH)"
else
    test_fail "UI_WIDTH out of bounds or not set ($UI_WIDTH)"
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
    echo -e "\n${GREEN}✓ All tests passed! Terminal detection verified.${NC}"
    exit 0
else
    exit 1
fi
