#!/usr/bin/env bash
# Test Suite: Dashboard Session Persistence (P17.5)
# Tests: layout save/restore, preset management, session recovery

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

test_layout_save_script_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Layout save/restore scripts exist"

    local save_script="$PROJECT_ROOT/scripts/save-layout.sh"
    local restore_script="$PROJECT_ROOT/scripts/restore-layout.sh"

    assert_file_exists "$save_script" "Save layout script exists"
    assert_executable "$save_script" "Save layout script is executable"
    assert_file_exists "$restore_script" "Restore layout script exists"
    assert_executable "$restore_script" "Restore layout script is executable"
}

test_layout_functions_exist() {
    echo -e "\n${CYAN}▶${NC} Test: Layout persistence functions exist"

    local functions=("tmux_save_layout" "tmux_restore_layout" "tmux_list_layouts")
    local all_exist=true

    for func in "${functions[@]}"; do
        if grep -q "^$func()" "$PROJECT_ROOT/scripts/utils.sh" || \
           grep -q "^$func()" "$PROJECT_ROOT/scripts/dashboard-launch.sh"; then
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

test_layout_directory_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Layout storage directory exists"

    local layout_dir="$PROJECT_ROOT/.ai-colab/layouts"

    if [[ -d "$layout_dir" ]] || grep -q "layouts\|tmux-layout" "$PROJECT_ROOT/scripts/save-layout.sh" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Layout storage directory configured"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Layout storage directory not configured"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_save_layout_uses_json() {
    echo -e "\n${CYAN}▶${NC} Test: Save layout uses JSON format"

    local save_script="$PROJECT_ROOT/scripts/save-layout.sh"

    if grep -q "json\|python.*json\|jq" "$save_script" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Save layout uses JSON format"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Save layout should use JSON format"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_restore_layout_reads_json() {
    echo -e "\n${CYAN}▶${NC} Test: Restore layout reads JSON format"

    local restore_script="$PROJECT_ROOT/scripts/restore-layout.sh"

    if grep -q "json\|python.*json\|jq" "$restore_script" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Restore layout reads JSON format"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Restore layout should read JSON format"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_named_layout_presets() {
    echo -e "\n${CYAN}▶${NC} Test: Named layout presets supported"

    local save_script="$PROJECT_ROOT/scripts/save-layout.sh"

    if grep -q "preset\|default\|coding\|review" "$save_script" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Named layout presets supported"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Named layout presets should be supported"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_dashboard_saves_layout_on_create() {
    echo -e "\n${CYAN}▶${NC} Test: Dashboard saves layout on creation"

    if grep -q "save-layout\|tmux_save_layout" "$PROJECT_ROOT/scripts/dashboard-launch.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Dashboard saves layout on creation"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Dashboard should save layout on creation"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Dashboard Session Persistence Test Suite (P17.5)   ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_layout_save_script_exists
    test_layout_functions_exist
    test_layout_directory_exists
    test_save_layout_uses_json
    test_restore_layout_reads_json
    test_named_layout_presets
    test_dashboard_saves_layout_on_create

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
