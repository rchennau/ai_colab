#!/usr/bin/env bash
# Web UI Comprehensive Test Script
# Tests all new endpoints and functionality

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="$PROJECT_ROOT/webui-venv"
WEBUI_DIR="$PROJECT_ROOT/webui"
PORT=8080
BASE_URL="http://localhost:$PORT"

# Activate virtual environment if it exists
if [[ -f "$PROJECT_ROOT/.venv/bin/activate" ]]; then
    source "$PROJECT_ROOT/.venv/bin/activate"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  $1                                                  ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
}

print_test() {
    echo -e "\n${CYAN}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
}

print_failure() {
    echo -e "${RED}✗ FAIL:${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ INFO:${NC} $1"
}

# Check if server is running
check_server() {
    print_test "Ensuring clean state (stopping any existing server)..."
    stop_server
    
    print_test "Checking if Web UI server is running..."
    
    if curl -s --connect-timeout 2 "$BASE_URL/health" >/dev/null 2>&1; then
        print_success "Server is running"
        return 0
    else
        print_info "Server not running, starting..."
        return 1
    fi
}

# Start server in background
start_server() {
    print_test "Starting Web UI server..."
    
    if [[ -d "$VENV_DIR" ]]; then
        source "$VENV_DIR/bin/activate"
    else
        print_info "Virtual environment not found at $VENV_DIR, using system Python"
    fi
    
    # Run from root to maintain module structure
    cd "$PROJECT_ROOT"
    
    # Start server in background
    export PYTHONPATH="$PROJECT_ROOT:${PYTHONPATH:-}"
    python3 webui/app_refactored.py --port $PORT > /tmp/webui.log 2>&1 &
    SERVER_PID=$!
    echo $SERVER_PID > /tmp/webui.pid
    
    # Wait for server to start
    print_info "Waiting for server to start (PID: $SERVER_PID)..."
    for i in {1..10}; do
        if curl -s --connect-timeout 1 "$BASE_URL/health" >/dev/null 2>&1; then
            print_success "Server started successfully"
            return 0
        fi
        sleep 1
    done
    
    print_failure "Server failed to start"
    cat /tmp/webui.log
    return 1
}

# Stop server
stop_server() {
    print_test "Stopping Web UI server..."
    
    # Try PID file first
    if [[ -f /tmp/webui.pid ]]; then
        local pid=$(cat /tmp/webui.pid)
        if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null || true
            print_success "Server stopped (PID: $pid)"
        fi
        rm -f /tmp/webui.pid
    fi
    
    # Kill any processes listening on our port
    local port_pid=$(lsof -t -i :$PORT 2>/dev/null || true)
    if [[ -n "$port_pid" ]]; then
        kill -9 $port_pid 2>/dev/null || true
        print_success "Killed processes on port $PORT (PIDs: $port_pid)"
    fi

    # Kill by process name as well
    pkill -9 -f "python.*webui/app.*.py" 2>/dev/null || true
    print_info "Server processes cleaned up"
}

# Test health endpoint
test_health() {
    print_test "Testing /health endpoint..."
    
    local response=$(curl -s "$BASE_URL/health")
    
    # Check for required fields
    if echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert 'status' in data, 'Missing status field'
assert 'checks' in data, 'Missing checks field'
assert 'tmux' in data['checks'], 'Missing tmux check'
assert 'hcom' in data['checks'], 'Missing hcom check'
assert 'disk' in data['checks'], 'Missing disk check'
print('Health check structure valid')
"; then
        print_success "Health endpoint working"
        echo "$response" | python3 -m json.tool | head -20
        return 0
    else
        print_failure "Health endpoint failed"
        echo "$response"
        return 1
    fi
}

# Test preflight endpoint
test_preflight() {
    print_test "Testing /api/preflight endpoint..."
    
    local response=$(curl -s "$BASE_URL/api/preflight")
    
    if echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert 'passed' in data, 'Missing passed field'
assert 'checks' in data, 'Missing checks field'
assert 'errors' in data, 'Missing errors field'
assert 'warnings' in data, 'Missing warnings field'
print(f'Pre-flight checks: {len(data[\"checks\"])} checks performed')
if data['errors']:
    print(f'Errors: {len(data[\"errors\"])}')
if data['warnings']:
    print(f'Warnings: {len(data[\"warnings\"])}')
"; then
        print_success "Pre-flight endpoint working"
        return 0
    else
        print_failure "Pre-flight endpoint failed"
        echo "$response"
        return 1
    fi
}

# Test session status endpoint
test_session_status() {
    print_test "Testing /api/session/status endpoint..."
    
    local response=$(curl -s "$BASE_URL/api/session/status")
    
    if echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert 'exists' in data, 'Missing exists field'
print(f'Session exists: {data[\"exists\"]}')
if data.get('exists'):
    print(f'Healthy: {data.get(\"healthy\", \"unknown\")}')
    print(f'Panes: {data.get(\"pane_count\", 0)}')
    print(f'Windows: {data.get(\"window_count\", 0)}')
"; then
        print_success "Session status endpoint working"
        return 0
    else
        print_failure "Session status endpoint failed"
        echo "$response"
        return 1
    fi
}

# Test agents endpoint
test_agents() {
    print_test "Testing /api/agents endpoint..."
    
    local response=$(curl -s "$BASE_URL/api/agents")
    
    if echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert 'agents' in data, 'Missing agents field'
assert 'count' in data, 'Missing count field'
print(f'Active agents: {data[\"count\"]}')
for agent in data.get('agents', [])[:5]:  # Show first 5
    print(f'  - {agent.get(\"name\", \"unknown\")}: {agent.get(\"status\", \"unknown\")}')
"; then
        print_success "Agents endpoint working"
        return 0
    else
        print_failure "Agents endpoint failed"
        echo "$response"
        return 1
    fi
}

# Test config endpoint
test_config() {
    print_test "Testing /api/config endpoint..."
    
    local response=$(curl -s "$BASE_URL/api/config")
    
    if echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print('Configuration loaded successfully')
print(f'Keys: {list(data.keys())[:5]}...')
"; then
        print_success "Config endpoint working"
        return 0
    else
        print_failure "Config endpoint failed"
        return 1
    fi
}

# Test status endpoint
test_status() {
    print_test "Testing /api/status endpoint..."
    
    local response=$(curl -s "$BASE_URL/api/status")
    
    if echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print('Status endpoint working')
if 'installation' in data:
    print(f'Installation: {data[\"installation\"].get(\"status\", \"unknown\")}')
"; then
        print_success "Status endpoint working"
        return 0
    else
        print_failure "Status endpoint failed"
        return 1
    fi
}

# Test dashboard launch endpoint
test_dashboard_launch() {
    print_test "Testing /api/dashboard/launch endpoint..."
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"conductor": true, "vllm": false}' \
        "$BASE_URL/api/dashboard/launch")
    
    if echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'status' in data:
    print(f'Launch status: {data[\"status\"]}')
    print(f'Message: {data.get(\"message\", \"none\")}')
"; then
        print_success "Dashboard launch endpoint working"
        return 0
    else
        print_failure "Dashboard launch endpoint failed"
        echo "$response"
        return 1
    fi
}

# Test frontend HTML
test_frontend() {
    print_test "Testing frontend HTML..."
    
    local response=$(curl -s "$BASE_URL/")
    
    # Temporarily disable pipefail for grep -q to avoid SIGPIPE errors with large HTML
    set +o pipefail
    local grep_status=0
    if echo "$response" | grep -q "ai-colab Web UI"; then
        print_success "Frontend HTML served correctly"
        
        # Check for new features in HTML
        if echo "$response" | grep -q "runPreflightCheck"; then
            echo -e "  ${GREEN}✓${NC} Pre-flight check function found"
        fi
        if echo "$response" | grep -q "recoverSession"; then
            echo -e "  ${GREEN}✓${NC} Session recovery function found"
        fi
        if echo "$response" | grep -q "refreshHealth"; then
            echo -e "  ${GREEN}✓${NC} Health check function found"
        fi
        if echo "$response" | grep -q "checkSession"; then
            echo -e "  ${GREEN}✓${NC} Session check function found"
        fi
        
        set -o pipefail
        return 0
    else
        set -o pipefail
        print_failure "Frontend HTML not served correctly"
        return 1
    fi
}

# Main test runner
main() {
    print_header "Web UI Comprehensive Test Suite"
    
    local tests_passed=0
    local tests_failed=0
    local server_started=false
    
    # Check if server is running
    if ! check_server; then
        if ! start_server; then
            print_failure "Could not start server"
            exit 1
        fi
        server_started=true
    fi
    
    echo ""
    print_header "Running API Tests"
    
    # Run tests
    if test_health; then ((tests_passed++)); else ((tests_failed++)); fi
    if test_preflight; then ((tests_passed++)); else ((tests_failed++)); fi
    if test_session_status; then ((tests_passed++)); else ((tests_failed++)); fi
    if test_agents; then ((tests_passed++)); else ((tests_failed++)); fi
    if test_config; then ((tests_passed++)); else ((tests_failed++)); fi
    if test_status; then ((tests_passed++)); else ((tests_failed++)); fi
    if test_dashboard_launch; then ((tests_passed++)); else ((tests_failed++)); fi
    if test_frontend; then ((tests_passed++)); else ((tests_failed++)); fi
    
    # Stop server if we started it
    if [[ "$server_started" == true ]]; then
        echo ""
        stop_server
    fi
    
    # Summary
    echo ""
    print_header "Test Summary"
    echo -e "  ${GREEN}Passed:${NC} $tests_passed"
    echo -e "  ${RED}Failed:${NC} $tests_failed"
    echo ""
    
    if [[ $tests_failed -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        exit 1
    fi
}

# Handle cleanup on exit
trap 'if [[ -f /tmp/webui.pid ]]; then stop_server; fi' EXIT

main "$@"
