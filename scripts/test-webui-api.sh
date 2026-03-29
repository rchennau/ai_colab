#!/usr/bin/env bash
# ai-colab WebUI API Test Suite
# Tests all WebUI API endpoints and functions

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# API base URL
API_BASE="${API_BASE:-http://localhost:8080}"

# Log file
LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/logs"
mkdir -p "$LOG_DIR"
TEST_LOG="$LOG_DIR/webui-api-test-$(date +%Y%m%d-%H%M%S).log"

# ============================================
# Test Helper Functions
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

# API test helper
test_api() {
    local method="$1"
    local endpoint="$2"
    local expected_status="$3"
    local data="$4"
    local description="$5"
    
    local response
    local http_code
    
    if [[ "$method" == "GET" ]]; then
        response=$(curl -s -w "\n%{http_code}" "${API_BASE}${endpoint}" 2>/dev/null)
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "${API_BASE}${endpoint}" 2>/dev/null)
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [[ "$http_code" == "$expected_status" ]]; then
        pass "$description (HTTP $http_code)"
        return 0
    else
        fail "$description (Expected HTTP $expected_status, got $http_code)"
        log "  Response: $body"
        return 1
    fi
}

# Check if WebUI is running
check_webui_running() {
    curl -s --max-time 5 "${API_BASE}/health" >/dev/null 2>&1
    return $?
}

# ============================================
# Health Endpoint Tests
# ============================================

test_health_endpoints() {
    section "Health Endpoint Tests"
    
    # Test /health
    test_api "GET" "/health" "200" "" "Health check endpoint"
    
    # Test /health/detailed
    test_api "GET" "/health/detailed" "200" "" "Detailed health check endpoint"
    
    # Test /health/logs
    test_api "GET" "/health/logs" "200" "" "Health logs endpoint"
    
    # Verify health response structure
    local health_response
    health_response=$(curl -s "${API_BASE}/health" 2>/dev/null)
    
    if echo "$health_response" | grep -q '"status"'; then
        pass "Health response contains status field"
    else
        fail "Health response missing status field"
    fi
    
    if echo "$health_response" | grep -q '"components"'; then
        pass "Health response contains components field"
    else
        fail "Health response missing components field"
    fi
}

# ============================================
# Logs Endpoint Tests
# ============================================

test_logs_endpoints() {
    section "Logs Endpoint Tests"
    
    # Test GET /api/logs (default 10 lines)
    test_api "GET" "/api/logs" "200" "" "Get logs (default 10 lines)"
    
    # Test GET /api/logs?lines=50
    test_api "GET" "/api/logs?lines=50" "200" "" "Get logs (50 lines)"
    
    # Verify logs response structure
    local logs_response
    logs_response=$(curl -s "${API_BASE}/api/logs" 2>/dev/null)
    
    if echo "$logs_response" | grep -q '"logs"'; then
        pass "Logs response contains logs field"
    else
        fail "Logs response missing logs field"
    fi
    
    if echo "$logs_response" | grep -q '"count"'; then
        pass "Logs response contains count field"
    else
        fail "Logs response missing count field"
    fi
    
    # Test POST /api/logs/rotate
    test_api "POST" "/api/logs/rotate" "200" "{}" "Rotate logs endpoint"
    
    # Test POST /api/logs/clear
    # Note: This clears logs, so run last
    test_api "POST" "/api/logs/clear" "200" "{}" "Clear logs endpoint"
}

# ============================================
# Status Endpoint Tests
# ============================================

test_status_endpoints() {
    section "Status Endpoint Tests"
    
    # Test GET /api/status
    test_api "GET" "/api/status" "200" "" "Get system status"
    
    # Verify status response structure
    local status_response
    status_response=$(curl -s "${API_BASE}/api/status" 2>/dev/null)
    
    if echo "$status_response" | grep -q '"installation"'; then
        pass "Status response contains installation field"
    else
        fail "Status response missing installation field"
    fi
}

# ============================================
# Terminal Endpoint Tests
# ============================================

test_terminal_endpoints() {
    section "Terminal Endpoint Tests"
    
    # Test GET /api/terminal/list
    test_api "GET" "/api/terminal/list" "200" "" "List active terminals"
    
    # Test POST /api/terminal/spawn (bash terminal)
    test_api "POST" "/api/terminal/spawn" "200" '{"id": "test-1", "type": "bash"}' "Spawn bash terminal"
    
    # Test POST /api/terminal/close
    test_api "POST" "/api/terminal/close" "200" '{"id": "test-1"}' "Close terminal"
    
    # Verify terminal list response
    local list_response
    list_response=$(curl -s "${API_BASE}/api/terminal/list" 2>/dev/null)
    
    if echo "$list_response" | grep -q '"terminals"'; then
        pass "Terminal list response contains terminals field"
    else
        fail "Terminal list response missing terminals field"
    fi
}

# ============================================
# Conductor Endpoint Tests
# ============================================

test_conductor_endpoints() {
    section "Conductor Endpoint Tests"
    
    # Test GET /api/conductor/status
    test_api "GET" "/api/conductor/status" "200" "" "Get conductor status"
    
    # Verify conductor status response
    local conductor_response
    conductor_response=$(curl -s "${API_BASE}/api/conductor/status" 2>/dev/null)
    
    if echo "$conductor_response" | grep -q '"available"'; then
        pass "Conductor status contains available field"
    else
        fail "Conductor status missing available field"
    fi
    
    if echo "$conductor_response" | grep -q '"project_root"'; then
        pass "Conductor status contains project_root field"
    else
        fail "Conductor status missing project_root field"
    fi
}

# ============================================
# Configuration Endpoint Tests
# ============================================

test_config_endpoints() {
    section "Configuration Endpoint Tests"
    
    # Test GET /api/config
    test_api "GET" "/api/config" "200" "" "Get configuration"
    
    # Test PUT /api/config (with minimal valid config)
    local config_data='{"version":"1.0.0","installation":{"status":"complete","pathway":"webui"},"llms":[],"modules":[],"compute":{"backend":"local"}}'
    test_api "PUT" "/api/config" "200" "$config_data" "Update configuration"
    
    # Test POST /api/config/validate
    test_api "POST" "/api/config/validate" "200" "$config_data" "Validate configuration"
}

# ============================================
# Profiles Endpoint Tests
# ============================================

test_profiles_endpoints() {
    section "Profiles Endpoint Tests"
    
    # Test GET /api/profiles
    test_api "GET" "/api/profiles" "200" "" "List profiles"
    
    # Test POST /api/profiles/save
    test_api "POST" "/api/profiles/save" "200" '{"name":"test-profile"}' "Save profile"
    
    # Test POST /api/profiles/delete
    test_api "POST" "/api/profiles/delete" "200" '{"name":"test-profile"}' "Delete profile"
}

# ============================================
# Modules Endpoint Tests
# ============================================

test_modules_endpoints() {
    section "Modules Endpoint Tests"
    
    # Test GET /api/modules
    test_api "GET" "/api/modules" "200" "" "List modules"
    
    # Test POST /api/modules/<id>/enable
    test_api "POST" "/api/modules/atari-8bit/enable" "200" "" "Enable module"
    
    # Test POST /api/modules/<id>/disable
    test_api "POST" "/api/modules/atari-8bit/disable" "200" "" "Disable module"
}

# ============================================
# Knowledge Base Endpoint Tests
# ============================================

test_kb_endpoints() {
    section "Knowledge Base Endpoint Tests"
    
    # Test GET /api/kb/search
    test_api "GET" "/api/kb/search?query=test" "200" "" "Search knowledge base"
    
    # Test GET /api/kb/index
    test_api "GET" "/api/kb/index" "200" "" "Get KB index"
}

# ============================================
# Shutdown Endpoint Tests
# ============================================

test_shutdown_endpoints() {
    section "Shutdown Endpoint Tests"
    
    # Test POST /api/shutdown
    test_api "POST" "/api/shutdown" "200" '{"session":"hcom-dashboard"}' "Shutdown system"
}

# ============================================
# Main Test Runner
# ============================================

main() {
    log ""
    log "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    log "${GREEN}║     ai-colab WebUI API Test Suite v1.0                   ║${NC}"
    log "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    log ""
    log "Test Log: $TEST_LOG"
    log "API Base: $API_BASE"
    log ""
    
    # Check if WebUI is running
    if ! check_webui_running; then
        log "${RED}Error: WebUI is not running at $API_BASE${NC}"
        log "Please start the WebUI server first:"
        log "  cd /home/rchennau/ai_colab"
        log "  python3 webui/app.py &"
        log ""
        exit 1
    fi
    
    log "${GREEN}✓ WebUI is running${NC}"
    log ""
    
    # Run test suites
    test_health_endpoints
    test_logs_endpoints
    test_status_endpoints
    test_terminal_endpoints
    test_conductor_endpoints
    test_config_endpoints
    test_profiles_endpoints
    test_modules_endpoints
    test_kb_endpoints
    test_shutdown_endpoints
    
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
