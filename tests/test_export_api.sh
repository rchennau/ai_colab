#!/usr/bin/env bash
# Test Suite: Historical Trending & Export (P24.4)
# Tests: export API endpoints, CSV/JSON export, Flask integration

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

test_export_api_file_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Export API file exists"

    assert_file_exists "$PROJECT_ROOT/webui/api/export.py" "Export API file exists"
}

test_export_api_syntax() {
    echo -e "\n${CYAN}▶${NC} Test: Export API syntax is valid"

    if python3 -m py_compile "$PROJECT_ROOT/webui/api/export.py" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Python syntax is valid"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Python syntax error"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_export_blueprint_registered() {
    echo -e "\n${CYAN}▶${NC} Test: Export blueprint is registered"

    if grep -q "export_bp" "$PROJECT_ROOT/webui/api/__init__.py" && \
       grep -q "export_bp" "$PROJECT_ROOT/webui/app_refactored.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Export blueprint is registered"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Export blueprint should be registered"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_export_has_csv_endpoint() {
    echo -e "\n${CYAN}▶${NC} Test: Export has CSV endpoint"

    if grep -q "/api/export/csv" "$PROJECT_ROOT/webui/api/export.py"; then
        echo -e "${GREEN}✓ PASS:${NC} CSV endpoint exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} CSV endpoint missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_export_has_json_endpoint() {
    echo -e "\n${CYAN}▶${NC} Test: Export has JSON endpoint"

    if grep -q "/api/export/json" "$PROJECT_ROOT/webui/api/export.py"; then
        echo -e "${GREEN}✓ PASS:${NC} JSON endpoint exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} JSON endpoint missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_export_has_summary_endpoint() {
    echo -e "\n${CYAN}▶${NC} Test: Export has summary endpoint"

    if grep -q "/api/export/summary" "$PROJECT_ROOT/webui/api/export.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Summary endpoint exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Summary endpoint missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_export_has_csv_function() {
    echo -e "\n${CYAN}▶${NC} Test: Export has CSV export function"

    if grep -q "export_to_csv" "$PROJECT_ROOT/webui/api/export.py"; then
        echo -e "${GREEN}✓ PASS:${NC} CSV export function exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} CSV export function missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_export_has_json_function() {
    echo -e "\n${CYAN}▶${NC} Test: Export has JSON export function"

    if grep -q "export_to_json" "$PROJECT_ROOT/webui/api/export.py"; then
        echo -e "${GREEN}✓ PASS:${NC} JSON export function exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} JSON export function missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_export_collects_fleet_state() {
    echo -e "\n${CYAN}▶${NC} Test: Export collects fleet state"

    if grep -q "collect_current_fleet_state" "$PROJECT_ROOT/webui/api/export.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Fleet state collection exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Fleet state collection missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_export_collects_historical_metrics() {
    echo -e "\n${CYAN}▶${NC} Test: Export collects historical metrics"

    if grep -q "collect_historical_metrics" "$PROJECT_ROOT/webui/api/export.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Historical metrics collection exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Historical metrics collection missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_export_collects_error_log() {
    echo -e "\n${CYAN}▶${NC} Test: Export collects error log"

    if grep -q "collect_error_log" "$PROJECT_ROOT/webui/api/export.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Error log collection exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Error log collection missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_export_csv_has_headers() {
    echo -e "\n${CYAN}▶${NC} Test: CSV export includes headers"

    if grep -q "writer.writerow" "$PROJECT_ROOT/webui/api/export.py"; then
        echo -e "${GREEN}✓ PASS:${NC} CSV export has headers"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} CSV export missing headers"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_export_json_has_summary() {
    echo -e "\n${CYAN}▶${NC} Test: JSON export includes summary"

    if grep -q "\"summary\"" "$PROJECT_ROOT/webui/api/export.py"; then
        echo -e "${GREEN}✓ PASS:${NC} JSON export has summary"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} JSON export missing summary"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_export_supports_days_parameter() {
    echo -e "\n${CYAN}▶${NC} Test: Export supports days parameter"

    if grep -q "days.*request.args" "$PROJECT_ROOT/webui/api/export.py"; then
        echo -e "${GREEN}✓ PASS:${NC} Export supports days parameter"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Export missing days parameter"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Historical Trending & Export Test Suite (P24.4)   ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_export_api_file_exists
    test_export_api_syntax
    test_export_blueprint_registered
    test_export_has_csv_endpoint
    test_export_has_json_endpoint
    test_export_has_summary_endpoint
    test_export_has_csv_function
    test_export_has_json_function
    test_export_collects_fleet_state
    test_export_collects_historical_metrics
    test_export_collects_error_log
    test_export_csv_has_headers
    test_export_json_has_summary
    test_export_supports_days_parameter

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
