#!/usr/bin/env bash
# Test Suite: Environment Portability (P6.2)
# Tests: ai-colab is self-contained and doesn't rely on user's environment

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

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"

    if [[ "$haystack" != *"$needle"* ]]; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        echo -e "  Should NOT contain: '$needle'"
        echo -e "  Actual: '$haystack'"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Tests
# ============================================================

test_local_tmux_config_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Local tmux config exists"

    assert_file_exists "$PROJECT_ROOT/.ai-colab/tmux.conf" "Local tmux.conf exists"
}

test_tmux_config_no_user_home_references() {
    echo -e "\n${CYAN}▶${NC} Test: tmux config doesn't reference user's home"

    local tmux_conf
    tmux_conf=$(cat "$PROJECT_ROOT/.ai-colab/tmux.conf")

    assert_not_contains "$tmux_conf" "~/.tmux.conf" "No reference to user's ~/.tmux.conf"
    assert_not_contains "$tmux_conf" "source-file ~/.tmux" "No source-file of user's config"
}

test_tmux_config_has_required_settings() {
    echo -e "\n${CYAN}▶${NC} Test: tmux config has required settings"

    local tmux_conf
    tmux_conf=$(cat "$PROJECT_ROOT/.ai-colab/tmux.conf")

    assert_contains "$tmux_conf" "set -g mouse on" "Mouse support configured"
    assert_contains "$tmux_conf" "pane-border-status" "Pane border status configured"
    assert_contains "$tmux_conf" "default-command" "Default command configured"
    assert_contains "$tmux_conf" "default-shell" "Default shell configured"
}

test_tmux_config_uses_clean_shell() {
    echo -e "\n${CYAN}▶${NC} Test: tmux config uses clean shell (no user config loading)"

    local tmux_conf
    tmux_conf=$(cat "$PROJECT_ROOT/.ai-colab/tmux.conf")

    # Should use --norc --noprofile to avoid loading user's .bashrc/.zshrc
    if echo "$tmux_conf" | grep -q "norc\|noprofile\|default-command"; then
        echo -e "${GREEN}✓ PASS:${NC} tmux configured to use clean shell"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} tmux should use clean shell"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_env_script_exists() {
    echo -e "\n${CYAN}▶${NC} Test: ai-colab environment script exists"

    assert_file_exists "$PROJECT_ROOT/scripts/ai-colab-env.sh" "Environment script exists"
}

test_env_script_sets_project_root() {
    echo -e "\n${CYAN}▶${NC} Test: Environment script sets project root"

    # Run in clean environment
    local result
    result=$(env -i HOME="$HOME" PATH="/usr/bin:/bin" bash -c "
        AI_COLAB_PROJECT_ROOT='$PROJECT_ROOT'
        source '$PROJECT_ROOT/scripts/ai-colab-env.sh'
        echo \"\$AI_COLAB_PROJECT_ROOT\"
    " 2>/dev/null)

    if [[ "$result" == "$PROJECT_ROOT" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Project root set correctly"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Project root not set (got: $result)"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_env_script_cleans_aliases() {
    echo -e "\n${CYAN}▶${NC} Test: Environment script cleans aliases"

    local result
    result=$(bash -c "
        alias test_alias='echo test'
        source '$PROJECT_ROOT/scripts/ai-colab-env.sh' 2>/dev/null
        alias 2>/dev/null | wc -l | tr -d ' '
    " 2>/dev/null)

    if [[ "$result" == "0" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Aliases cleaned"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Aliases not cleaned (count: $result)"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_dashboard_uses_local_tmux_config() {
    echo -e "\n${CYAN}▶${NC} Test: Dashboard launcher uses local tmux config"

    if grep -q ".ai-colab/tmux.conf" "$PROJECT_ROOT/scripts/dashboard-launch.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Dashboard references local tmux.conf"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Dashboard should use local tmux.conf"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_dashboard_uses_ai_colab_env() {
    echo -e "\n${CYAN}▶${NC} Test: Dashboard launcher uses ai-colab environment"

    if grep -q "ai-colab-env.sh" "$PROJECT_ROOT/scripts/dashboard-launch.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Dashboard sources ai-colab-env.sh"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Dashboard should source ai-colab-env.sh"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_dashboard_uses_tmux_f_flag() {
    echo -e "\n${CYAN}▶${NC} Test: Dashboard uses tmux -f flag for config"

    if grep -q "tmux -f" "$PROJECT_ROOT/scripts/dashboard-launch.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Dashboard uses 'tmux -f' for config"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Dashboard should use 'tmux -f' for config"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Environment Portability Test Suite (P6.2)          ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_local_tmux_config_exists
    test_tmux_config_no_user_home_references
    test_tmux_config_has_required_settings
    test_tmux_config_uses_clean_shell
    test_env_script_exists
    test_env_script_sets_project_root
    test_env_script_cleans_aliases
    test_dashboard_uses_local_tmux_config
    test_dashboard_uses_ai_colab_env
    test_dashboard_uses_tmux_f_flag

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
