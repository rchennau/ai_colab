#!/usr/bin/env bash
# Test Suite: Actionable Insights Engine (P24.3)
# Tests: insights API endpoints, recommendation generation, Flask integration

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

# ============================================================
# Tests
# ============================================================

test_insights_api_file_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Insights API file exists"

    assert_file_exists "$PROJECT_ROOT/webui/api/insights.py" "Insights API file exists"
}

test_insights_api_syntax() {
    echo -e "\n${CYAN}▶${NC} Test: Insights API syntax is valid"

    if python3 -m py_compile "$PROJECT_ROOT/webui/api/insights.py" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Python syntax is valid"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Python syntax error"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_insights_blueprint_registered() {
    echo -e "\n${CYAN}▶${NC} Test: Insights blueprint is registered"

    if grep -q "insights_bp" "$PROJECT_ROOT/webui/api/__init__.py" && \
       grep -q "insights_bp" "$PROJECT_ROOT/webui/app_refactored.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Insights blueprint is registered"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Insights blueprint should be registered"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_insights_has_summary_endpoint() {
    echo -e "\n${CYAN}▶${NC} Test: Insights has summary endpoint"

    if grep -q "/api/insights/summary" "$PROJECT_ROOT/webui/api/insights.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Summary endpoint exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Summary endpoint missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_insights_has_agents_endpoint() {
    echo -e "\n${CYAN}▶${NC} Test: Insights has agents endpoint"

    if grep -q "/api/insights/agents" "$PROJECT_ROOT/webui/api/insights.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Agents endpoint exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Agents endpoint missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_insights_has_routing_endpoint() {
    echo -e "\n${CYAN}▶${NC} Test: Insights has routing endpoint"

    if grep -q "/api/insights/routing" "$PROJECT_ROOT/webui/api/insights.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Routing endpoint exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Routing endpoint missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_insights_has_cost_endpoint() {
    echo -e "\n${CYAN}▶${NC} Test: Insights has cost endpoint"

    if grep -q "/api/insights/cost" "$PROJECT_ROOT/webui/api/insights.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Cost endpoint exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Cost endpoint missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_insights_has_capacity_endpoint() {
    echo -e "\n${CYAN}▶${NC} Test: Insights has capacity endpoint"

    if grep -q "/api/insights/capacity" "$PROJECT_ROOT/webui/api/insights.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Capacity endpoint exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Capacity endpoint missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_insights_has_agent_insights_function() {
    echo -e "\n${CYAN}▶${NC} Test: Insights has agent insights function"

    if grep -q "generate_agent_insights" "$PROJECT_ROOT/webui/api/insights.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Agent insights function exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Agent insights function missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_insights_has_routing_recommendations() {
    echo -e "\n${CYAN}▶${NC} Test: Insights has routing recommendations"

    if grep -q "generate_routing_recommendations" "$PROJECT_ROOT/webui/api/insights.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Routing recommendations function exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Routing recommendations function missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_insights_has_cost_recommendations() {
    echo -e "\n${CYAN}▶${NC} Test: Insights has cost recommendations"

    if grep -q "generate_cost_recommendations" "$PROJECT_ROOT/webui/api/insights.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Cost recommendations function exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Cost recommendations function missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_insights_has_capacity_recommendations() {
    echo -e "\n${CYAN}▶${NC} Test: Insights has capacity recommendations"

    if grep -q "generate_capacity_recommendations" "$PROJECT_ROOT/webui/api/insights.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Capacity recommendations function exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Capacity recommendations function missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_insights_detects_stale_heartbeat() {
    echo -e "\n${CYAN}▶${NC} Test: Insights detects stale heartbeat"

    if grep -q "stale_heartbeat\|stale.*heartbeat" "$PROJECT_ROOT/webui/api/insights.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Stale heartbeat detection exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Stale heartbeat detection missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_insights_recommends_preferred_agent() {
    echo -e "\n${CYAN}▶${NC} Test: Insights recommends preferred agent"

    if grep -q "preferred_agent" "$PROJECT_ROOT/webui/api/insights.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Preferred agent recommendation exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Preferred agent recommendation missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_insights_suggests_load_balancing() {
    echo -e "\n${CYAN}▶${NC} Test: Insights suggests load balancing"

    if grep -q "load_balance\|load.*balance" "$PROJECT_ROOT/webui/api/insights.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Load balancing suggestion exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Load balancing suggestion missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Actionable Insights Engine Test Suite (P24.3)     ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_insights_api_file_exists
    test_insights_api_syntax
    test_insights_blueprint_registered
    test_insights_has_summary_endpoint
    test_insights_has_agents_endpoint
    test_insights_has_routing_endpoint
    test_insights_has_cost_endpoint
    test_insights_has_capacity_endpoint
    test_insights_has_agent_insights_function
    test_insights_has_routing_recommendations
    test_insights_has_cost_recommendations
    test_insights_has_capacity_recommendations
    test_insights_detects_stale_heartbeat
    test_insights_recommends_preferred_agent
    test_insights_suggests_load_balancing

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
