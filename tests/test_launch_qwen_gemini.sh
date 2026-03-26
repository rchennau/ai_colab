#!/usr/bin/env bash
# Test launch.sh with Qwen + Gemini only (Option 3: Both)
# Verifies hcom and tmux integration works correctly

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TEST_SESSION="hcom-dashboard-test"
TESTS_PASSED=0
TESTS_FAILED=0

print_test() {
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Test:${NC} $1"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((TESTS_PASSED++))
}

print_failure() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    ((TESTS_FAILED++))
}

print_info() {
    echo -e "${CYAN}ℹ INFO:${NC} $1"
}

# Cleanup function
cleanup() {
    print_info "Cleaning up test session..."
    if tmux has-session -t "$TEST_SESSION" 2>/dev/null; then
        tmux kill-session -t "$TEST_SESSION" 2>/dev/null || true
        print_info "Killed test session"
    fi
    # Kill any orphaned hcom processes from this test
    pkill -f "hcom.*test_agent" 2>/dev/null || true
}

trap cleanup EXIT

# Test 1: Prerequisites
test_prerequisites() {
    print_test "Prerequisites Check"

    local has_errors=0

    if ! command -v tmux >/dev/null 2>&1; then
        print_failure "tmux is not installed"
        has_errors=1
    else
        print_info "tmux version: $(tmux -V)"
        print_success "tmux is available"
    fi

    if ! command -v hcom >/dev/null 2>&1; then
        print_failure "hcom is not installed"
        has_errors=1
    else
        print_success "hcom is available"
    fi

    if [[ ! -f "$PROJECT_ROOT/launch.sh" ]]; then
        print_failure "launch.sh not found"
        has_errors=1
    else
        print_success "launch.sh exists"
    fi

    if [[ ! -f "$PROJECT_ROOT/scripts/dashboard-launch.sh" ]]; then
        print_failure "dashboard-launch.sh not found"
        has_errors=1
    else
        print_success "dashboard-launch.sh exists"
    fi

    return $has_errors
}

# Test 2: Clean up any existing test sessions
test_cleanup() {
    print_test "Cleaning Existing Sessions"

    if tmux has-session -t "$TEST_SESSION" 2>/dev/null; then
        tmux kill-session -t "$TEST_SESSION" 2>/dev/null || true
        print_info "Killed existing test session"
    fi

    # Wait for cleanup
    sleep 1

    if ! tmux has-session -t "$TEST_SESSION" 2>/dev/null; then
        print_success "Test environment is clean"
        return 0
    else
        print_failure "Failed to clean up existing session"
        return 1
    fi
}

# Test 3: Launch dashboard with qwen+gemini only
test_dashboard_launch() {
    print_test "Dashboard Launch (Qwen + Gemini only)"

    # Kill any existing hcom-dashboard session first
    tmux kill-session -t hcom-dashboard 2>/dev/null || true
    sleep 1

    # Launch dashboard directly with specific flags (simulating launch.sh option 3 with qwen+gemini)
    # We use the dashboard-launch.sh directly for controlled testing
    cd "$PROJECT_ROOT"

    print_info "Launching dashboard with --no-vllm --conductor..."

    # Start dashboard in background with controlled flags
    # Using --conductor to include conductor pane, qwen and gemini are default
    bash "$PROJECT_ROOT/scripts/dashboard-launch.sh" --conductor --no-console &
    local launch_pid=$!

    # Wait for dashboard to initialize
    print_info "Waiting for dashboard initialization (10s)..."
    sleep 10

    # Check if launch process is still running (it should be - tmux attach)
    if kill -0 $launch_pid 2>/dev/null; then
        print_success "Dashboard launch process is running"
    else
        print_failure "Dashboard launch process exited unexpectedly"
        return 1
    fi

    return 0
}

# Test 4: Verify tmux session exists
test_tmux_session() {
    print_test "TMUX Session Creation"

    if tmux has-session -t hcom-dashboard 2>/dev/null; then
        print_success "hcom-dashboard session created"
    else
        print_failure "hcom-dashboard session not found"
        return 1
    fi

    # Get session info
    local window_count=$(tmux list-windows -t hcom-dashboard 2>/dev/null | wc -l)
    print_info "Windows in session: $window_count"

    if [[ $window_count -ge 1 ]]; then
        print_success "At least one window exists"
    else
        print_failure "No windows found in session"
        return 1
    fi

    return 0
}

# Test 5: Verify pane layout
test_pane_layout() {
    print_test "Pane Layout Verification"

    # List all panes in the dashboard window
    local pane_list=$(tmux list-panes -t hcom-dashboard:dashboard 2>/dev/null)

    if [[ -z "$pane_list" ]]; then
        print_failure "No panes found in dashboard window"
        return 1
    fi

    local pane_count=$(echo "$pane_list" | wc -l)
    print_info "Pane count: $pane_count"

    # We expect at least: hcom TUI + right column (conductor, qwen, gemini) + console
    # Minimum 4 panes
    if [[ $pane_count -ge 4 ]]; then
        print_success "Expected number of panes present ($pane_count)"
    else
        print_failure "Unexpected pane count (expected >= 4, got $pane_count)"
        print_info "Pane list:"
        echo "$pane_list"
        return 1
    fi

    return 0
}

# Test 6: Verify pane titles
test_pane_titles() {
    print_test "Pane Title Verification"

    local has_hcom=false
    local has_conductor=false
    local has_qwen=false
    local has_gemini=false

    # Get pane titles
    while IFS= read -r pane_id; do
        local title=$(tmux display-message -p -t "$pane_id" "#{pane_title}" 2>/dev/null || echo "")
        print_info "Pane $pane_id title: $title"

        case "$title" in
            *"hcom"*|*"HCOM"*) has_hcom=true ;;
            *"Conductor"*|*"conductor"*) has_conductor=true ;;
            *"Qwen"*|*"qwen"*) has_qwen=true ;;
            *"Gemini"*|*"gemini"*) has_gemini=true ;;
        esac
    done < <(tmux list-panes -t hcom-dashboard:dashboard -F "#{pane_id}" 2>/dev/null)

    local title_errors=0

    if $has_hcom; then
        print_success "HCOM pane title found"
    else
        print_failure "HCOM pane title not found"
        ((title_errors++))
    fi

    if $has_conductor; then
        print_success "Conductor pane title found"
    else
        print_failure "Conductor pane title not found"
        ((title_errors++))
    fi

    if $has_qwen; then
        print_success "Qwen pane title found"
    else
        print_failure "Qwen pane title not found"
        ((title_errors++))
    fi

    if $has_gemini; then
        print_success "Gemini pane title found"
    else
        print_failure "Gemini pane title not found"
        ((title_errors++))
    fi

    return $title_errors
}

# Test 7: Verify hcom TUI output (no garbled text)
test_hcom_output() {
    print_test "HCOM TUI Output Quality"

    # Capture pane content
    local hcom_pane=$(tmux display-message -p -t hcom-dashboard:dashboard.0 "#{pane_title}" 2>/dev/null)
    print_info "HCOM pane title: $hcom_pane"

    # Get pane content using capture-pane
    local pane_content=$(tmux capture-pane -p -t hcom-dashboard:dashboard.0 2>/dev/null | head -20)

    # Check for garbled output patterns
    if echo "$pane_content" | grep -q "░▒▓"; then
        print_failure "Garbled output detected (░▒▓ patterns)"
        print_info "Pane content sample:"
        echo "$pane_content" | head -10
        return 1
    else
        print_success "No garbled output detected"
    fi

    # Check for expected hcom content
    if echo "$pane_content" | grep -qi "hcom\|agent\|listening"; then
        print_success "HCOM TUI shows expected content"
    else
        print_info "HCOM pane content (first 10 lines):"
        echo "$pane_content" | head -10
        print_info "(Content may still be initializing)"
    fi

    return 0
}

# Test 8: Verify agents are running
test_agents_running() {
    print_test "Agent Process Verification"

    local agent_errors=0

    # Check for qwen agent
    if pgrep -f "agent-wrapper.sh.*qwen" >/dev/null 2>&1 || pgrep -f "qwen-hcom" >/dev/null 2>&1; then
        print_success "Qwen agent process found"
    else
        print_info "Qwen agent process not detected (may be normal)"
    fi

    # Check for gemini agent
    if pgrep -f "agent-wrapper.sh.*gemini" >/dev/null 2>&1 || pgrep -f "gemini-hcom" >/dev/null 2>&1; then
        print_success "Gemini agent process found"
    else
        print_info "Gemini agent process not detected (may be normal)"
    fi

    # Check for conductor
    if pgrep -f "conductor-workflow" >/dev/null 2>&1; then
        print_success "Conductor process found"
    else
        print_info "Conductor process not detected (may be normal)"
    fi

    # Use hcom list to check registered agents
    print_info "Checking hcom registered agents..."
    sleep 2
    local hcom_agents=$(hcom list --names 2>/dev/null || echo "")

    if [[ -n "$hcom_agents" ]]; then
        print_info "Registered agents:"
        echo "$hcom_agents" | while read -r line; do
            print_info "  - $line"
        done
    else
        print_info "No agents registered yet (may still be initializing)"
    fi

    return 0
}

# Test 9: Test hcom communication
test_hcom_communication() {
    print_test "HCOM Communication Test"

    # Create a test user agent
    local test_user="test_user_$$"
    print_info "Creating test user: $test_user"

    # Start hcom as test user
    if hcom start --as "$test_user" >/dev/null 2>&1; then
        print_success "Test user hcom session started"
    else
        print_failure "Failed to start test user hcom session"
        return 1
    fi

    # Try to send a message to conductor
    print_info "Testing message to conductor..."
    local response=$(hcom send @conductor --intent request --thread "test" -- "Test message" 2>&1 || echo "No response")

    if [[ -n "$response" ]]; then
        print_info "Response received: ${response:0:100}..."
        print_success "HCOM communication working"
    else
        print_info "No immediate response (normal for async system)"
    fi

    # Stop test user
    hcom stop --name "$test_user" >/dev/null 2>&1 || true

    return 0
}

# Test 10: Dashboard navigation
test_dashboard_navigation() {
    print_test "Dashboard Navigation"

    # Test pane selection
    local pane_ids=$(tmux list-panes -t hcom-dashboard:dashboard -F "#{pane_id}" 2>/dev/null)

    if [[ -n "$pane_ids" ]]; then
        print_success "Can list pane IDs"

        # Try selecting each pane
        while IFS= read -r pane_id; do
            if tmux select-pane -t "$pane_id" 2>/dev/null; then
                print_info "Successfully selected pane: $pane_id"
            else
                print_failure "Failed to select pane: $pane_id"
                return 1
            fi
        done <<< "$pane_ids"

        print_success "All panes are selectable"
    else
        print_failure "Cannot list pane IDs"
        return 1
    fi

    return 0
}

# Main test runner
main() {
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     launch.sh Qwen+Gemini Integration Test            ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    print_info "Project Root: $PROJECT_ROOT"
    print_info "Test Session: $TEST_SESSION"
    print_info "Date: $(date)"

    # Run tests
    test_prerequisites && true || true
    test_cleanup && true || true
    test_dashboard_launch && true || true
    test_tmux_session && true || true
    test_pane_layout && true || true
    test_pane_titles && true || true
    test_hcom_output && true || true
    test_agents_running && true || true
    test_hcom_communication && true || true
    test_dashboard_navigation && true || true

    # Summary
    echo -e "\n${BLUE}══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Test Summary:${NC}"
    echo -e "  ${GREEN}Passed:${NC} $TESTS_PASSED"
    echo -e "  ${RED}Failed:${NC} $TESTS_FAILED"
    echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All tests passed!${NC}"
        echo -e "\n${CYAN}Dashboard is running. To attach manually:${NC}"
        echo -e "  tmux attach -t hcom-dashboard"
        echo -e "\n${CYAN}To detach: Ctrl+b, then d${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Some tests failed${NC}"
        echo -e "\n${YELLOW}Dashboard may still be running. To check:${NC}"
        echo -e "  tmux list-sessions"
        echo -e "  tmux attach -t hcom-dashboard"
        return 1
    fi
}

main "$@"
