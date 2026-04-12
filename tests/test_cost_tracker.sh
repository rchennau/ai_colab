#!/usr/bin/env bash
# Test Suite: Cost Optimization & Budget Engine (P5.3)
# Tests: budget manager, cost estimation, alerts, shell wrapper

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

assert_executable() {
    local file="$1"
    local message="$2"

    if [[ -x "$file" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        echo -e "  Not executable: '$file'"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# Clean up test budget DB
cleanup_test_budget() {
    rm -rf "$PROJECT_ROOT/.ai-colab/budget" 2>/dev/null || true
}

# ============================================================
# Tests
# ============================================================

test_budget_files_exist() {
    echo -e "\n${CYAN}▶${NC} Test: Budget files exist"

    assert_file_exists "$PROJECT_ROOT/scripts/budget-manager.py" "Budget manager exists"
    assert_file_exists "$PROJECT_ROOT/scripts/cost-tracker.sh" "Cost tracker shell wrapper exists"
    assert_file_exists "$PROJECT_ROOT/config/pricing.json" "Pricing config exists"
    assert_file_exists "$PROJECT_ROOT/config/budget-config.json" "Budget config exists"
}

test_budget_scripts_executable() {
    echo -e "\n${CYAN}▶${NC} Test: Budget scripts are executable"

    assert_executable "$PROJECT_ROOT/scripts/cost-tracker.sh" "Shell wrapper is executable"
}

test_budget_manager_syntax() {
    echo -e "\n${CYAN}▶${NC} Test: Budget manager Python syntax is valid"

    if python3 -m py_compile "$PROJECT_ROOT/scripts/budget-manager.py" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Python syntax is valid"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Python syntax error"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_pricing_config_valid_json() {
    echo -e "\n${CYAN}▶${NC} Test: Pricing config is valid JSON"

    if python3 -c "import json; json.load(open('$PROJECT_ROOT/config/pricing.json'))" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Pricing config is valid JSON"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Pricing config is not valid JSON"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_budget_config_valid_json() {
    echo -e "\n${CYAN}▶${NC} Test: Budget config is valid JSON"

    if python3 -c "import json; json.load(open('$PROJECT_ROOT/config/budget-config.json'))" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Budget config is valid JSON"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Budget config is not valid JSON"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_record_and_query_usage() {
    echo -e "\n${CYAN}▶${NC} Test: Record and query usage"

    cleanup_test_budget

    # Record usage
    python3 "$PROJECT_ROOT/scripts/budget-manager.py" record \
        --agent test_agent \
        --input-tokens 1000 \
        --output-tokens 500 2>&1

    # Query status
    local status
    status=$(python3 "$PROJECT_ROOT/scripts/budget-manager.py" status \
        --agent test_agent 2>&1)

    if echo "$status" | grep -q "total_input_tokens" && \
       echo "$status" | grep -q "1000"; then
        echo -e "${GREEN}✓ PASS:${NC} Usage recorded and queried correctly"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Usage not queried correctly"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    cleanup_test_budget
}

test_cost_estimation() {
    echo -e "\n${CYAN}▶${NC} Test: Cost estimation works"

    cleanup_test_budget

    # Record usage
    local result
    result=$(python3 "$PROJECT_ROOT/scripts/budget-manager.py" record \
        --agent test_agent \
        --input-tokens 1000000 \
        --output-tokens 500000 2>&1)

    # Check cost is estimated (gemini default: $3.50 input + $10.50 output per 1M)
    if echo "$result" | grep -q "estimated_cost"; then
        echo -e "${GREEN}✓ PASS:${NC} Cost estimation works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Cost estimation failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    cleanup_test_budget
}

test_set_budget() {
    echo -e "\n${CYAN}▶${NC} Test: Set budget command"

    cleanup_test_budget

    # Set budget
    local result
    result=$(python3 "$PROJECT_ROOT/scripts/budget-manager.py" set-budget \
        --agent test_agent \
        --budget 100 2>&1)

    if echo "$result" | grep -qi "budget set\|100"; then
        echo -e "${GREEN}✓ PASS:${NC} Budget set successfully"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Budget set failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    cleanup_test_budget
}

test_budget_alerts() {
    echo -e "\n${CYAN}▶${NC} Test: Budget alerts command"

    cleanup_test_budget

    # Get alerts (should be empty initially)
    local alerts
    alerts=$(python3 "$PROJECT_ROOT/scripts/budget-manager.py" alerts 2>&1)

    if echo "$alerts" | grep -qi "no.*alerts\|alerts"; then
        echo -e "${GREEN}✓ PASS:${NC} Budget alerts command works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Budget alerts command failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    cleanup_test_budget
}

test_cost_ranking() {
    echo -e "\n${CYAN}▶${NC} Test: Cost efficiency ranking"

    cleanup_test_budget

    # Record usage for multiple agents
    python3 "$PROJECT_ROOT/scripts/budget-manager.py" record \
        --agent gemini --input-tokens 1000000 --output-tokens 500000 2>&1

    python3 "$PROJECT_ROOT/scripts/budget-manager.py" record \
        --agent qwen --input-tokens 1000000 --output-tokens 500000 2>&1

    # Get ranking
    local ranking
    ranking=$(python3 "$PROJECT_ROOT/scripts/budget-manager.py" ranking 2>&1)

    if echo "$ranking" | grep -q "gemini" && echo "$ranking" | grep -q "qwen"; then
        echo -e "${GREEN}✓ PASS:${NC} Cost ranking works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Cost ranking failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    cleanup_test_budget
}

test_shell_wrapper_help() {
    echo -e "\n${CYAN}▶${NC} Test: Shell wrapper help works"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/cost-tracker.sh" --help 2>&1)

    if echo "$output" | grep -q "Usage\|--agent\|--budget"; then
        echo -e "${GREEN}✓ PASS:${NC} Shell wrapper help works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Shell wrapper help does not work"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Cost Optimization Test Suite (P5.3)                ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_budget_files_exist
    test_budget_scripts_executable
    test_budget_manager_syntax
    test_pricing_config_valid_json
    test_budget_config_valid_json
    test_record_and_query_usage
    test_cost_estimation
    test_set_budget
    test_budget_alerts
    test_cost_ranking
    test_shell_wrapper_help

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
