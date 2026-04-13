#!/usr/bin/env bash
# Test Suite: Agent Analytics Web UI API (P24.1)
# Tests: analytics API endpoints, data collection, response format

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

assert_valid_json() {
    local json="$1"
    local message="$2"

    if echo "$json" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message - invalid JSON"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Tests
# ============================================================

test_analytics_api_file_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics API file exists"

    assert_file_exists "$PROJECT_ROOT/webui/api/analytics.py" "Analytics API file exists"
}

test_analytics_api_syntax() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics API syntax is valid"

    if python3 -m py_compile "$PROJECT_ROOT/webui/api/analytics.py" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Python syntax is valid"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Python syntax error"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_blueprint_registered() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics blueprint is registered"

    if grep -q "analytics_bp" "$PROJECT_ROOT/webui/api/__init__.py" && \
       grep -q "analytics_bp" "$PROJECT_ROOT/webui/app_refactored.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Analytics blueprint is registered"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Analytics blueprint should be registered"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_has_summary_endpoint() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics has summary endpoint"

    if grep -q "/api/analytics/summary" "$PROJECT_ROOT/webui/api/analytics.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Summary endpoint exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Summary endpoint missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_has_agents_endpoint() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics has agents endpoint"

    if grep -q "/api/analytics/agents" "$PROJECT_ROOT/webui/api/analytics.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Agents endpoint exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Agents endpoint missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_has_agent_detail_endpoint() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics has agent detail endpoint"

    if grep -q "/api/analytics/agent/" "$PROJECT_ROOT/webui/api/analytics.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Agent detail endpoint exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Agent detail endpoint missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_has_tasks_endpoint() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics has tasks endpoint"

    if grep -q "/api/analytics/tasks" "$PROJECT_ROOT/webui/api/analytics.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Tasks endpoint exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Tasks endpoint missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_has_errors_endpoint() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics has errors endpoint"

    if grep -q "/api/analytics/errors" "$PROJECT_ROOT/webui/api/analytics.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Errors endpoint exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Errors endpoint missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_has_cost_endpoint() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics has cost endpoint"

    if grep -q "/api/analytics/cost" "$PROJECT_ROOT/webui/api/analytics.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Cost endpoint exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Cost endpoint missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_has_trends_endpoint() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics has trends endpoint"

    if grep -q "/api/analytics/trends" "$PROJECT_ROOT/webui/api/analytics.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Trends endpoint exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Trends endpoint missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_collects_agent_metrics() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics collects agent metrics"

    if grep -q "collect_agent_metrics" "$PROJECT_ROOT/webui/api/analytics.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Agent metrics collection exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Agent metrics collection missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_collects_task_history() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics collects task history"

    if grep -q "collect_task_history" "$PROJECT_ROOT/webui/api/analytics.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Task history collection exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Task history collection missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_collects_error_distribution() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics collects error distribution"

    if grep -q "collect_error_distribution" "$PROJECT_ROOT/webui/api/analytics.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Error distribution collection exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Error distribution collection missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_collects_cost_metrics() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics collects cost metrics"

    if grep -q "collect_cost_metrics" "$PROJECT_ROOT/webui/api/analytics.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Cost metrics collection exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Cost metrics collection missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_db_schema() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics DB schema is created"

    if grep -q "agent_metrics\|task_history\|error_log" "$PROJECT_ROOT/webui/api/analytics.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Analytics DB schema exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Analytics DB schema missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Agent Analytics Web UI API Test Suite (P24.1)     ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_analytics_api_file_exists
    test_analytics_api_syntax
    test_analytics_blueprint_registered
    test_analytics_has_summary_endpoint
    test_analytics_has_agents_endpoint
    test_analytics_has_agent_detail_endpoint
    test_analytics_has_tasks_endpoint
    test_analytics_has_errors_endpoint
    test_analytics_has_cost_endpoint
    test_analytics_has_trends_endpoint
    test_analytics_collects_agent_metrics
    test_analytics_collects_task_history
    test_analytics_collects_error_distribution
    test_analytics_collects_cost_metrics
    test_analytics_db_schema

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
