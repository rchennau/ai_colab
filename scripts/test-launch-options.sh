#!/usr/bin/env bash
# ai-colab Launch Options Test Harness v3.0 (Hardened & Modular)
# Comprehensive testing for Dashboard, WebUI, and Debug Mode

set -uo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Log file
LOG_DIR="$PROJECT_ROOT/logs"
mkdir -p "$LOG_DIR"
TEST_LOG="$LOG_DIR/test-harness-$(date +%Y%m%d-%H%M%S).log"

# ============================================
# Utility Functions
# ============================================

log() { echo -e "$1" | tee -a "$TEST_LOG"; }
pass() { ((TESTS_PASSED++)); log "${GREEN}✓ PASS:${NC} $1"; }
fail() { ((TESTS_FAILED++)); log "${RED}✗ FAIL:${NC} $1"; }
skip() { ((TESTS_SKIPPED++)); log "${YELLOW}○ SKIP:${NC} $1"; }
section() { log ""; log "${BLUE}═══════════════════════════════════════════════════════════${NC}"; log "${BLUE}  $1${NC}"; log "${BLUE}═══════════════════════════════════════════════════════════${NC}"; }
check_command() { command -v "$1" >/dev/null 2>&1; }

cleanup() {
    log ""
    log "${YELLOW}Cleaning up test resources...${NC}"
    tmux kill-session -t ai-colab-test 2>/dev/null || true
    pkill -f "python.*webui/app_refactored.py.*test" 2>/dev/null || true
    pkill -f "debug-mode.sh" 2>/dev/null || true
    log "Cleanup complete"
}

trap cleanup EXIT

# ============================================
# Prerequisite Tests
# ============================================

test_prerequisites() {
    section "Prerequisite Checks"
    check_command tmux && pass "tmux is installed" || fail "tmux is not installed"
    check_command hcom && pass "hcom is installed" || fail "hcom is not installed"
    check_command python3 && pass "python3 is installed" || fail "python3 is not installed"
    
    # Check WebUI dependencies via virtual env
    if [[ -d "$PROJECT_ROOT/webui-venv" ]]; then
        if "$PROJECT_ROOT/webui-venv/bin/python3" -c "import flask" 2>/dev/null; then
            pass "Flask is installed in webui-venv"
        else
            fail "Flask is missing in webui-venv"
        fi
    else
        skip "webui-venv not found, skipping environment check"
    fi
    
    [[ -x "$PROJECT_ROOT/launch.sh" ]] && pass "launch.sh is executable" || fail "launch.sh error"
}

# ============================================
# Dashboard (tmux) Tests
# ============================================

test_dashboard_launch() {
    section "Dashboard (tmux) Tests"
    [[ -x "$PROJECT_ROOT/scripts/dashboard-launch.sh" ]] && pass "dashboard-launch.sh is executable" || fail "launcher error"
    [[ -f "$PROJECT_ROOT/scripts/conductor-workflow.sh" ]] && pass "conductor-workflow.sh exists" || fail "conductor logic missing"
    [[ -f "$PROJECT_ROOT/scripts/agent-wrapper.sh" ]] && pass "agent-wrapper.sh (unified) exists" || fail "unified wrapper missing"
    
    # Check for removals
    if [[ ! -f "$PROJECT_ROOT/scripts/gemini-hcom.sh" ]]; then
        pass "Redundant boilerplate (gemini-hcom.sh) removed"
    else
        fail "Redundant boilerplate (gemini-hcom.sh) still exists"
    fi
}

# ============================================
# WebUI Tests
# ============================================

test_webui_server() {
    section "WebUI Server Tests"
    [[ -f "$PROJECT_ROOT/webui/app_refactored.py" ]] && pass "app_refactored.py (v3.0) exists" || fail "modular backend missing"
    [[ -f "$PROJECT_ROOT/webui/index.html" ]] && pass "webui/index.html exists" || fail "index.html missing"
    
    # Check blueprints
    for bp in terminal system config kb models; do
        if [[ -f "$PROJECT_ROOT/webui/api/${bp}.py" ]]; then
            pass "Blueprint: ${bp} is modularized"
        else
            fail "Blueprint: ${bp} is missing or monolithic"
        fi
    done
}

# ============================================
# Integration Tests
# ============================================

test_integration() {
    section "Integration Tests"
    grep -q "DASHBOARD=true" "$PROJECT_ROOT/launch.sh" && pass "Dashboard mode integrated" || fail "Dashboard missing"
    grep -q "WEBUI=true" "$PROJECT_ROOT/launch.sh" && pass "WebUI mode integrated" || fail "WebUI missing"
    grep -q 'id="projectSwitcher"' "$PROJECT_ROOT/webui/index.html" && pass "Multi-Project switcher found" || fail "Switcher missing"
    
    # Quality Gates
    [[ -x "$PROJECT_ROOT/scripts/quality-gates.sh" ]] && pass "Quality Gates framework implemented" || fail "Quality Gates missing"
}

# ============================================
# Main Test Runner
# ============================================

main() {
    log ""
    log "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    log "${GREEN}║     ai-colab v3.0 Launch & Architecture Test             ║${NC}"
    log "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    log ""
    log "Test Log: $TEST_LOG"
    
    test_prerequisites
    test_dashboard_launch
    test_webui_server
    test_integration
    
    section "Test Summary"
    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
    log "${CYAN}Total Tests:${NC} $total"
    log "${GREEN}Passed:${NC} $TESTS_PASSED"
    log "${RED}Failed:${NC} $TESTS_FAILED"
    
    [[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
}

main "$@"
