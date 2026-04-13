#!/usr/bin/env bash
# Test Suite: Agent Analytics Dashboard (P24.2)
# Tests: HTML structure, JavaScript, CSS styles, navigation integration

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

test_analytics_js_file_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics JS file exists"

    assert_file_exists "$PROJECT_ROOT/webui/static/js/analytics.js" "Analytics JS file exists"
}

test_analytics_html_section_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics HTML section exists"

    if grep -q "analytics-page" "$PROJECT_ROOT/webui/index.html"; then
        echo -e "${GREEN}✓ PASS:${NC} Analytics page exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Analytics page missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_nav_button_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics nav button exists"

    if grep -q 'data-page="analytics"' "$PROJECT_ROOT/webui/index.html"; then
        echo -e "${GREEN}✓ PASS:${NC} Analytics nav button exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Analytics nav button missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_summary_section_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics summary section exists"

    if grep -q "analytics-summary" "$PROJECT_ROOT/webui/index.html"; then
        echo -e "${GREEN}✓ PASS:${NC} Analytics summary section exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Analytics summary section missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_agents_section_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics agents section exists"

    if grep -q "analytics-agents" "$PROJECT_ROOT/webui/index.html"; then
        echo -e "${GREEN}✓ PASS:${NC} Analytics agents section exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Analytics agents section missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_errors_section_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics errors section exists"

    if grep -q "analytics-errors" "$PROJECT_ROOT/webui/index.html"; then
        echo -e "${GREEN}✓ PASS:${NC} Analytics errors section exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Analytics errors section missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_cost_section_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics cost section exists"

    if grep -q "analytics-cost" "$PROJECT_ROOT/webui/index.html"; then
        echo -e "${GREEN}✓ PASS:${NC} Analytics cost section exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Analytics cost section missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_trends_section_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics trends section exists"

    if grep -q "analytics-trends" "$PROJECT_ROOT/webui/index.html"; then
        echo -e "${GREEN}✓ PASS:${NC} Analytics trends section exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Analytics trends section missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_css_styles_exist() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics CSS styles exist"

    local has_summary_grid has_agent_card has_error_bar has_trend_row
    has_summary_grid=$(grep -c "summary-grid" "$PROJECT_ROOT/webui/index.html")
    has_agent_card=$(grep -c "agent-card" "$PROJECT_ROOT/webui/index.html")
    has_error_bar=$(grep -c "error-bar" "$PROJECT_ROOT/webui/index.html")
    has_trend_row=$(grep -c "trend-row" "$PROJECT_ROOT/webui/index.html")

    if [[ $has_summary_grid -gt 0 && $has_agent_card -gt 0 && $has_error_bar -gt 0 && $has_trend_row -gt 0 ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Analytics CSS styles exist"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Analytics CSS styles missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_js_has_fetch_functions() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics JS has fetch functions"

    local has_fetch_summary has_fetch_agents has_fetch_trends
    has_fetch_summary=$(grep -c "fetchAnalyticsSummary" "$PROJECT_ROOT/webui/static/js/analytics.js")
    has_fetch_agents=$(grep -c "fetchAnalyticsAgents" "$PROJECT_ROOT/webui/static/js/analytics.js")
    has_fetch_trends=$(grep -c "fetchAnalyticsTrends" "$PROJECT_ROOT/webui/static/js/analytics.js")

    if [[ $has_fetch_summary -gt 0 && $has_fetch_agents -gt 0 && $has_fetch_trends -gt 0 ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Analytics JS has fetch functions"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Analytics JS missing fetch functions"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_js_has_render_functions() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics JS has render functions"

    local has_render_summary has_render_agents has_render_cost
    has_render_summary=$(grep -c "renderSummaryCard" "$PROJECT_ROOT/webui/static/js/analytics.js")
    has_render_agents=$(grep -c "renderAgentCards" "$PROJECT_ROOT/webui/static/js/analytics.js")
    has_render_cost=$(grep -c "renderCostMetrics" "$PROJECT_ROOT/webui/static/js/analytics.js")

    if [[ $has_render_summary -gt 0 && $has_render_agents -gt 0 && $has_render_cost -gt 0 ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Analytics JS has render functions"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Analytics JS missing render functions"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_js_has_auto_refresh() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics JS has auto-refresh"

    if grep -q "setInterval" "$PROJECT_ROOT/webui/static/js/analytics.js"; then
        echo -e "${GREEN}✓ PASS:${NC} Analytics JS has auto-refresh"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Analytics JS missing auto-refresh"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_script_included_in_html() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics script included in HTML"

    if grep -q "analytics.js" "$PROJECT_ROOT/webui/index.html"; then
        echo -e "${GREEN}✓ PASS:${NC} Analytics script included in HTML"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Analytics script not included in HTML"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_analytics_page_in_load_page_data() {
    echo -e "\n${CYAN}▶${NC} Test: Analytics page in loadPageData"

    if grep -q "case 'analytics'" "$PROJECT_ROOT/webui/index.html"; then
        echo -e "${GREEN}✓ PASS:${NC} Analytics page in loadPageData"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Analytics page not in loadPageData"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Agent Analytics Dashboard Test Suite (P24.2)      ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_analytics_js_file_exists
    test_analytics_html_section_exists
    test_analytics_nav_button_exists
    test_analytics_summary_section_exists
    test_analytics_agents_section_exists
    test_analytics_errors_section_exists
    test_analytics_cost_section_exists
    test_analytics_trends_section_exists
    test_analytics_css_styles_exist
    test_analytics_js_has_fetch_functions
    test_analytics_js_has_render_functions
    test_analytics_js_has_auto_refresh
    test_analytics_script_included_in_html
    test_analytics_page_in_load_page_data

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
