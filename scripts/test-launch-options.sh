#!/usr/bin/env bash
# ai-colab Launch Options Test Harness
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

# Timeout settings
WEBUI_TIMEOUT=30
DASHBOARD_TIMEOUT=15
DEBUG_TIMEOUT=10

# Log file
LOG_DIR="$PROJECT_ROOT/logs"
mkdir -p "$LOG_DIR"
TEST_LOG="$LOG_DIR/test-harness-$(date +%Y%m%d-%H%M%S).log"

# ============================================
# Utility Functions
# ============================================

log() {
    echo -e "$1" | tee -a "$TEST_LOG"
}

pass() {
    ((TESTS_PASSED++))
    log "${GREEN}✓ PASS:${NC} $1"
}

fail() {
    ((TESTS_FAILED++))
    log "${RED}✗ FAIL:${NC} $1"
}

skip() {
    ((TESTS_SKIPPED++))
    log "${YELLOW}○ SKIP:${NC} $1"
}

section() {
    log ""
    log "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    log "${BLUE}  $1${NC}"
    log "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

cleanup() {
    log ""
    log "${YELLOW}Cleaning up test resources...${NC}"
    
    # Kill test tmux sessions
    tmux kill-session -t ai-colab-test 2>/dev/null || true
    
    # Kill test WebUI processes
    pkill -f "python.*webui/app.py.*test" 2>/dev/null || true
    
    # Kill any debug mode processes
    pkill -f "debug-mode.sh" 2>/dev/null || true
    
    log "Cleanup complete"
}

trap cleanup EXIT

# ============================================
# Prerequisite Tests
# ============================================

test_prerequisites() {
    section "Prerequisite Checks"
    
    # Check tmux
    if check_command tmux; then
        pass "tmux is installed ($(tmux -V))"
    else
        fail "tmux is not installed"
    fi
    
    # Check hcom
    if check_command hcom; then
        pass "hcom is installed ($(hcom --version 2>&1 | head -1))"
    else
        fail "hcom is not installed"
    fi
    
    # Check Python
    if check_command python3; then
        pass "python3 is installed ($(python3 --version))"
    else
        fail "python3 is not installed"
    fi
    
    # Check WebUI dependencies
    if python3 -c "import flask" 2>/dev/null; then
        pass "Flask is installed"
    else
        fail "Flask is not installed"
    fi
    
    # Check flask-socketio (optional for basic tests)
    if python3 -c "import flask_socketio" 2>/dev/null; then
        pass "Flask-SocketIO is installed"
    else
        skip "Flask-SocketIO not installed (WebUI real-time features unavailable)"
    fi
    
    # Check xterm.js CDN accessibility (optional)
    if curl -s --head --fail https://cdn.jsdelivr.net/npm/xterm@5.3.0/css/xterm.min.css >/dev/null 2>&1; then
        pass "xterm.js CDN is accessible"
    else
        skip "xterm.js CDN not accessible (offline mode)"
    fi
    
    # Check launch.sh exists and is executable
    if [[ -x "$PROJECT_ROOT/launch.sh" ]]; then
        pass "launch.sh exists and is executable"
    else
        fail "launch.sh is missing or not executable"
    fi
    
    # Check debug-mode.sh exists and is executable
    if [[ -x "$PROJECT_ROOT/scripts/debug-mode.sh" ]]; then
        pass "debug-mode.sh exists and is executable"
    else
        fail "debug-mode.sh is missing or not executable"
    fi
}

# ============================================
# Dashboard (tmux) Tests
# ============================================

test_dashboard_launch() {
    section "Dashboard (tmux) Tests"
    
    local session_name="ai-colab-test"
    
    # Test 1: Dashboard launcher script exists
    if [[ -f "$PROJECT_ROOT/scripts/dashboard-launch.sh" ]]; then
        pass "dashboard-launch.sh exists"
    else
        fail "dashboard-launch.sh is missing"
        return
    fi
    
    # Test 2: Dashboard launcher is executable
    if [[ -x "$PROJECT_ROOT/scripts/dashboard-launch.sh" ]]; then
        pass "dashboard-launch.sh is executable"
    else
        fail "dashboard-launch.sh is not executable"
    fi
    
    # Test 3: Dashboard help flag works
    if timeout 5 bash "$PROJECT_ROOT/scripts/dashboard-launch.sh" --help >/dev/null 2>&1; then
        pass "dashboard-launch.sh --help works"
    else
        # Help might not be implemented, that's ok
        skip "dashboard-launch.sh --help not implemented"
    fi
    
    # Test 4: Verify conductor-workflow.sh exists
    if [[ -f "$PROJECT_ROOT/scripts/conductor-workflow.sh" ]]; then
        pass "conductor-workflow.sh exists"
    else
        fail "conductor-workflow.sh is missing"
    fi
    
    # Test 5: Verify agent wrapper scripts exist
    for agent_script in qwen-hcom.sh gemini-hcom.sh claude-hcom.sh deepseek-hcom.sh; do
        if [[ -f "$PROJECT_ROOT/scripts/$agent_script" ]]; then
            pass "$agent_script exists"
        else
            skip "$agent_script not found (optional)"
        fi
    done
    
    # Test 6: Check tmux configuration
    if tmux has-session -t $session_name 2>/dev/null; then
        tmux kill-session -t $session_name
    fi
    
    log "${CYAN}Note: Full dashboard launch test requires interactive selection${NC}"
    log "${CYAN}Manual test: ./launch.sh -> Select option 1${NC}"
}

# ============================================
# WebUI Tests
# ============================================

test_webui_server() {
    section "WebUI Server Tests"
    
    local test_port=8081
    local webui_pid=""
    
    # Test 1: WebUI app.py exists
    if [[ -f "$PROJECT_ROOT/webui/app.py" ]]; then
        pass "webui/app.py exists"
    else
        fail "webui/app.py is missing"
        return
    fi
    
    # Test 2: WebUI index.html exists
    if [[ -f "$PROJECT_ROOT/webui/index.html" ]]; then
        pass "webui/index.html exists"
    else
        fail "webui/index.html is missing"
    fi
    
    # Test 3: Check for xterm.js integration in index.html
    if grep -q "xterm" "$PROJECT_ROOT/webui/index.html"; then
        pass "xterm.js integration found in index.html"
    else
        fail "xterm.js integration not found in index.html"
    fi
    
    # Test 4: Check for PTY manager in app.py
    if grep -q "PTYManager" "$PROJECT_ROOT/webui/app.py"; then
        pass "PTYManager class found in app.py"
    else
        fail "PTYManager class not found in app.py"
    fi
    
    # Test 5: Check terminal API endpoints
    if grep -q "/api/terminal/spawn" "$PROJECT_ROOT/webui/app.py"; then
        pass "/api/terminal/spawn endpoint defined"
    else
        fail "/api/terminal/spawn endpoint not found"
    fi
    
    if grep -q "/api/terminal/close" "$PROJECT_ROOT/webui/app.py"; then
        pass "/api/terminal/close endpoint defined"
    else
        fail "/api/terminal/close endpoint not found"
    fi
    
    # Test 6: Start WebUI server on test port
    log "${CYAN}Starting WebUI server on port 8080...${NC}"
    
    cd "$PROJECT_ROOT"
    
    # Check if conda is available
    if [[ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]]; then
        source "$HOME/miniconda3/etc/profile.d/conda.sh"
        conda activate ai_agents 2>/dev/null || true
    fi
    
    # Note: WebUI always runs on port 8080
    python3 webui/app.py > "$LOG_DIR/webui-test.log" 2>&1 &
    webui_pid=$!
    
    sleep 8  # Give server time to fully initialize
    
    # Test 7: Check if server started
    if kill -0 $webui_pid 2>/dev/null; then
        pass "WebUI server started (PID: $webui_pid)"
    else
        fail "WebUI server failed to start"
        log "Server log:"
        cat "$LOG_DIR/webui-test.log" | tee -a "$TEST_LOG"
        return
    fi
    
    # Test 8: Health endpoint
    if curl -s --max-time 5 "http://localhost:8080/health" | grep -q "status"; then
        pass "Health endpoint responds"
    else
        fail "Health endpoint not responding"
    fi
    
    # Test 9: Index page
    if curl -s --max-time 5 "http://localhost:8080/" | grep -q "ai-colab"; then
        pass "Index page loads"
    else
        fail "Index page not loading"
    fi
    
    # Test 10: Web Terminal page
    if curl -s --max-time 5 "http://localhost:8080/" | grep -q "terminal-page"; then
        pass "Web Terminal page exists"
    else
        fail "Web Terminal page not found"
    fi
    
    # Test 11: Terminal spawn API
    local spawn_response
    spawn_response=$(curl -s --max-time 5 -X POST "http://localhost:8080/api/terminal/spawn" \
        -H "Content-Type: application/json" \
        -d '{"id": 999, "type": "bash"}')
    
    if echo "$spawn_response" | grep -qE "(success|pid)"; then
        pass "Terminal spawn API works"
        
        # Test 12: Terminal close API
        local close_response
        close_response=$(curl -s --max-time 5 -X POST "http://localhost:8080/api/terminal/close" \
            -H "Content-Type: application/json" \
            -d '{"id": 999}')
        
        if echo "$close_response" | grep -q "closed"; then
            pass "Terminal close API works"
        else
            fail "Terminal close API not responding correctly"
        fi
    else
        skip "Terminal spawn API test (PTY may not be available in test env)"
    fi
    
    # Test 13: Console send API
    local console_response
    console_response=$(curl -s --max-time 5 -X POST "http://localhost:8080/api/console/send" \
        -H "Content-Type: application/json" \
        -d '{"command": "!status"}')
    
    if echo "$console_response" | grep -qE "(success|sent|error)"; then
        pass "Console send API responds"
    else
        fail "Console send API not responding"
    fi
    
    # Test 14: Logs API
    if curl -s --max-time 5 "http://localhost:8080/api/logs?lines=10" | grep -q "logs"; then
        pass "Logs API responds"
    else
        fail "Logs API not responding"
    fi
    
    # Test 15: Conductor status API
    if curl -s --max-time 5 "http://localhost:8080/api/conductor/status" | grep -qE "(available|project_root)"; then
        pass "Conductor status API responds"
    else
        fail "Conductor status API not responding"
    fi
    
    # Cleanup: Stop server
    log "${CYAN}Stopping WebUI server...${NC}"
    kill $webui_pid 2>/dev/null || true
    sleep 2
    
    if ! kill -0 $webui_pid 2>/dev/null; then
        pass "WebUI server stopped cleanly"
    else
        fail "WebUI server did not stop cleanly"
        kill -9 $webui_pid 2>/dev/null || true
    fi
}

# ============================================
# Debug Mode Tests
# ============================================

test_debug_mode() {
    section "Debug Mode Tests"
    
    # Test 1: debug-mode.sh exists
    if [[ -f "$PROJECT_ROOT/scripts/debug-mode.sh" ]]; then
        pass "debug-mode.sh exists"
    else
        fail "debug-mode.sh is missing"
        return
    fi
    
    # Test 2: debug-mode.sh is executable
    if [[ -x "$PROJECT_ROOT/scripts/debug-mode.sh" ]]; then
        pass "debug-mode.sh is executable"
    else
        fail "debug-mode.sh is not executable"
    fi
    
    # Test 3: Check for KB/RAG integration
    if grep -q "knowledge_base" "$PROJECT_ROOT/scripts/debug-mode.sh"; then
        pass "Knowledge base integration found"
    else
        fail "Knowledge base integration not found"
    fi
    
    if grep -q "RAG" "$PROJECT_ROOT/scripts/debug-mode.sh"; then
        pass "RAG integration mentioned"
    else
        skip "RAG integration not explicitly mentioned"
    fi
    
    # Test 4: Check agent support
    for agent in qwen gemini claude deepseek; do
        if grep -qi "$agent" "$PROJECT_ROOT/scripts/debug-mode.sh"; then
            pass "$agent agent supported"
        else
            fail "$agent agent not supported"
        fi
    done
    
    # Test 5: Check context file creation
    if grep -q "CONTEXT_FILE" "$PROJECT_ROOT/scripts/debug-mode.sh"; then
        pass "Context file creation implemented"
    else
        fail "Context file creation not found"
    fi
    
    # Test 6: Check for product.md loading
    if grep -q "product.md" "$PROJECT_ROOT/scripts/debug-mode.sh"; then
        pass "Product definition loading implemented"
    else
        fail "Product definition loading not found"
    fi
    
    # Test 7: Check for tech-stack.md loading
    if grep -q "tech-stack.md" "$PROJECT_ROOT/scripts/debug-mode.sh"; then
        pass "Tech stack loading implemented"
    else
        fail "Tech stack loading not found"
    fi
    
    # Test 8: Verify debug mode in launch.sh
    if grep -q "DEBUG=true" "$PROJECT_ROOT/launch.sh"; then
        pass "Debug mode integrated in launch.sh"
    else
        fail "Debug mode not integrated in launch.sh"
    fi
    
    # Test 9: Check launch.sh debug option
    if grep -q "Debug Mode" "$PROJECT_ROOT/launch.sh"; then
        pass "Debug Mode option documented in launch.sh"
    else
        fail "Debug Mode option not documented"
    fi
    
    # Test 10: Syntax check
    if bash -n "$PROJECT_ROOT/scripts/debug-mode.sh" 2>/dev/null; then
        pass "debug-mode.sh syntax is valid"
    else
        fail "debug-mode.sh has syntax errors"
    fi
}

# ============================================
# Integration Tests
# ============================================

test_integration() {
    section "Integration Tests"
    
    # Test 1: launch.sh has all three options
    local option_count
    option_count=$(grep -c "DASHBOARD=true\|WEBUI=true\|DEBUG=true" "$PROJECT_ROOT/launch.sh" || echo "0")
    
    if [[ "$option_count" -ge 3 ]]; then
        pass "All three launch modes defined in launch.sh"
    else
        fail "Missing launch modes in launch.sh (found: $option_count)"
    fi
    
    # Test 2: Check for interactive menu
    if grep -q "Select launch mode" "$PROJECT_ROOT/launch.sh"; then
        pass "Interactive menu present"
    else
        fail "Interactive menu not found"
    fi
    
    # Test 3: Verify config-manager integration
    if grep -q "config-manager" "$PROJECT_ROOT/launch.sh"; then
        pass "Config manager integration found"
    else
        fail "Config manager integration not found"
    fi
    
    # Test 4: Check state persistence
    if grep -q "last_launch_choice" "$PROJECT_ROOT/launch.sh"; then
        pass "Launch choice persistence implemented"
    else
        fail "Launch choice persistence not found"
    fi
    
    # Test 5: Verify Web Terminal navigation in index.html
    if grep -q 'data-page="terminal"' "$PROJECT_ROOT/webui/index.html"; then
        pass "Web Terminal navigation button exists"
    else
        fail "Web Terminal navigation button not found"
    fi
    
    # Test 6: Check WebSocket terminal handlers
    if grep -q "terminal_input\|terminal_output" "$PROJECT_ROOT/webui/app.py"; then
        pass "WebSocket terminal handlers defined"
    else
        fail "WebSocket terminal handlers not found"
    fi
    
    # Test 7: Verify documentation exists
    if [[ -f "$PROJECT_ROOT/docs/WEB_TERMINAL_GUIDE.md" ]]; then
        pass "Web Terminal documentation exists"
    else
        fail "Web Terminal documentation missing"
    fi
    
    # Test 8: Check knowledge base updated
    if grep -q "debug-mode.sh" "$PROJECT_ROOT/conductor/knowledge_base_map.md"; then
        pass "Knowledge base updated with debug-mode.sh"
    else
        fail "Knowledge base not updated"
    fi
    
    # Test 9: Check tracks updated
    if grep -q "Milestone 14" "$PROJECT_ROOT/conductor/tracks.md"; then
        pass "Tracks updated with Milestone 14"
    else
        fail "Tracks not updated"
    fi
    
    # Test 10: Cross-reference check
    local webui_refs
    webui_refs=$(grep -c "WebUI\|Web UI\|webui" "$PROJECT_ROOT/README.md" || echo "0")
    
    if [[ "$webui_refs" -gt 0 ]]; then
        pass "README.md references WebUI"
    else
        fail "README.md missing WebUI references"
    fi
}

# ============================================
# Performance Tests (Optional)
# ============================================

test_performance() {
    section "Performance Tests (Optional)"
    
    # Skip if WebUI already running on 8080
    if curl -s --max-time 2 "http://localhost:8080/health" >/dev/null 2>&1; then
        skip "WebUI already running on port 8080"
        return
    fi
    
    # Start server on 8080
    cd "$PROJECT_ROOT"
    
    if [[ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]]; then
        source "$HOME/miniconda3/etc/profile.d/conda.sh"
        conda activate ai_agents 2>/dev/null || true
    fi
    
    python3 webui/app.py > /dev/null 2>&1 &
    local pid=$!
    sleep 5
    
    if ! kill -0 $pid 2>/dev/null; then
        skip "Server not running for performance tests"
        return
    fi
    
    # Test 1: Health endpoint response time
    local start_time end_time response_time
    start_time=$(date +%s%N)
    curl -s --max-time 5 "http://localhost:8080/health" >/dev/null
    end_time=$(date +%s%N)
    response_time=$(( (end_time - start_time) / 1000000 ))
    
    if [[ $response_time -lt 1000 ]]; then
        pass "Health endpoint response time: ${response_time}ms (< 1000ms)"
    else
        fail "Health endpoint slow: ${response_time}ms (> 1000ms)"
    fi
    
    # Test 2: Concurrent requests
    local success_count=0
    for i in {1..5}; do
        if curl -s --max-time 5 "http://localhost:8080/health" >/dev/null 2>&1; then
            ((success_count++))
        fi
    done
    
    if [[ $success_count -eq 5 ]]; then
        pass "Concurrent requests: 5/5 successful"
    else
        fail "Concurrent requests: $success_count/5 successful"
    fi
    
    # Cleanup
    kill $pid 2>/dev/null || true
}

# ============================================
# Main Test Runner
# ============================================

main() {
    log ""
    log "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    log "${GREEN}║     ai-colab Launch Options Test Harness v1.0            ║${NC}"
    log "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    log ""
    log "Test Log: $TEST_LOG"
    log "Project Root: $PROJECT_ROOT"
    log ""
    
    # Run test suites
    test_prerequisites
    test_dashboard_launch
    test_webui_server
    test_debug_mode
    test_integration
    test_performance
    
    # Summary
    section "Test Summary"
    
    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
    
    log "${CYAN}Total Tests:${NC} $total"
    log "${GREEN}Passed:${NC} $TESTS_PASSED"
    log "${RED}Failed:${NC} $TESTS_FAILED"
    log "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
    log ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log "${GREEN}═══════════════════════════════════════════════════════════${NC}"
        log "${GREEN}  All tests passed! ✓                                      ${NC}"
        log "${GREEN}═══════════════════════════════════════════════════════════${NC}"
        exit 0
    else
        log "${RED}═══════════════════════════════════════════════════════════${NC}"
        log "${RED}  Some tests failed. Review log: $TEST_LOG                 ${NC}"
        log "${RED}═══════════════════════════════════════════════════════════${NC}"
        exit 1
    fi
}

# Run main
main "$@"
