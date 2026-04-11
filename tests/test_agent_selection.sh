#!/usr/bin/env bash
# Test Suite: Intelligent Agent Selection (P16.4)
# Tests: capability registry, task analysis, agent matching, fallback routing

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CAPABILITIES_FILE="$PROJECT_ROOT/config/agent-capabilities.json"

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

assert_gt() {
    local a="$1"
    local b="$2"
    local message="$3"

    if (( $(echo "$a > $b" | bc -l 2>/dev/null || echo "0") )); then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        echo -e "  Expected $a > $b"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# Helper: run agent selection function
run_agent_match() {
    local task_description="$1"
    local available_agents="$2"  # comma-separated list

    (
        export PROJECT_ROOT="$PROJECT_ROOT"
        export CAPABILITIES_FILE="$CAPABILITIES_FILE"
        source "$PROJECT_ROOT/scripts/utils.sh" >/dev/null 2>&1
        agent_select_best "$task_description" "$available_agents"
    ) 2>&1
}

run_task_analysis() {
    local task_description="$1"

    (
        export PROJECT_ROOT="$PROJECT_ROOT"
        export CAPABILITIES_FILE="$CAPABILITIES_FILE"
        source "$PROJECT_ROOT/scripts/utils.sh" >/dev/null 2>&1
        agent_analyze_task "$task_description"
    ) 2>&1
}

run_capability_get() {
    local agent_name="$1"
    local capability="$2"

    (
        export PROJECT_ROOT="$PROJECT_ROOT"
        export CAPABILITIES_FILE="$CAPABILITIES_FILE"
        source "$PROJECT_ROOT/scripts/utils.sh" >/dev/null 2>&1
        agent_get_capability "$agent_name" "$capability"
    ) 2>&1
}

# ============================================================
# Tests
# ============================================================

test_capabilities_file_valid() {
    echo -e "\n${CYAN}▶${NC} Test: Capabilities file exists and is valid JSON"

    if [[ -f "$CAPABILITIES_FILE" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Capabilities file exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Capabilities file not found"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    if command -v python3 >/dev/null 2>&1; then
        local json_valid
        json_valid=$(python3 -c "import json; json.load(open('$CAPABILITIES_FILE')); print('valid')" 2>&1)
        assert_equals "valid" "$json_valid" "Capabilities is valid JSON"
    else
        echo -e "${YELLOW}⊘ SKIP:${NC} python3 not available"
    fi
}

test_capability_scores_exist() {
    echo -e "\n${CYAN}▶${NC} Test: All agents have capability scores"

    local agents=("gemini" "qwen" "claude" "deepseek" "nemoclaw" "vllm")
    local caps=("reasoning" "coding" "architecture" "documentation" "optimization" "review")

    for agent in "${agents[@]}"; do
        for cap in "${caps[@]}"; do
            local score
            score=$(run_capability_get "$agent" "$cap")
            if [[ -n "$score" && "$score" != "0" ]]; then
                echo -e "${GREEN}✓ PASS:${NC} $agent.$cap = $score"
                ((TESTS_PASSED++))
            else
                echo -e "${RED}✗ FAIL:${NC} $agent.$cap missing or zero"
                ((TESTS_FAILED++))
            fi
            ((TESTS_RUN++))
        done
    done
}

test_task_analysis_code_heavy() {
    echo -e "\n${CYAN}▶${NC} Test: Task analysis identifies code-heavy tasks"

    local result
    result=$(run_task_analysis "Implement a new API endpoint for user authentication with rate limiting")

    assert_contains "$result" "code_heavy" "Code-heavy task type detected"
}

test_task_analysis_architecture() {
    echo -e "\n${CYAN}▶${NC} Test: Task analysis identifies architecture tasks"

    local result
    result=$(run_task_analysis "Design the system Architecture for distributed message queue")

    assert_contains "$result" "architecture" "Architecture task type detected"
}

test_task_analysis_documentation() {
    echo -e "\n${CYAN}▶${NC} Test: Task analysis identifies documentation tasks"

    local result
    result=$(run_task_analysis "Write comprehensive documentation for the REST API endpoints and create a tutorial")

    assert_contains "$result" "documentation" "Documentation task type detected"
}

test_agent_selection_code_to_qwen() {
    echo -e "\n${CYAN}▶${NC} Test: Code-heavy task selects best coding agent"

    local result
    result=$(run_agent_match "Implement unit tests for the authentication module and refactor the database layer" "gemini,qwen,claude,deepseek")

    # Claude has the highest weighted score for code-heavy tasks
    # (coding=0.85 + strong reasoning/review = 0.805 weighted score)
    # Qwen has coding=0.9 but lower scores in other areas
    if [[ "$result" == *"claude"* || "$result" == *"qwen"* ]]; then
        echo -e "${GREEN}✓ PASS:${NC} High-coding agent selected for code-heavy task ($result)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Expected Claude or Qwen, got: $result"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_agent_selection_architecture_to_gemini() {
    echo -e "\n${CYAN}▶${NC} Test: Architecture task selects Gemini or nemoclaw"

    local result
    result=$(run_agent_match "Design the Architecture for the new plugin system with dependency injection" "gemini,qwen,nemoclaw")

    # Gemini (0.9) or nemoclaw (0.95) should be selected
    if [[ "$result" == *"gemini"* || "$result" == *"nemoclaw"* ]]; then
        echo -e "${GREEN}✓ PASS:${NC} High-architecture agent selected ($result)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Expected Gemini or nemoclaw, got: $result"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_agent_selection_fallback() {
    echo -e "\n${CYAN}▶${NC} Test: Fallback to next-best agent when optimal is unavailable"

    # Qwen is best for coding, but if Qwen is not available, Claude (0.85) should be next
    local result
    result=$(run_agent_match "Implement and fix bugs in the authentication code and refactor the database scripts" "gemini,claude,deepseek")

    # Without Qwen, Claude has the best coding score (0.85)
    if [[ "$result" == *"claude"* ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Claude selected as fallback for code task (Qwen unavailable)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Expected Claude as fallback, got: $result"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_agent_selection_no_available_agents() {
    echo -e "\n${CYAN}▶${NC} Test: No agents available returns empty"

    local result
    result=$(run_agent_match "Implement something" "")

    if [[ -z "$result" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Empty result when no agents available"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Expected empty result, got: $result"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_agent_selection_single_agent() {
    echo -e "\n${CYAN}▶${NC} Test: Single available agent always selected"

    local result
    result=$(run_agent_match "Any task" "gemini")

    assert_equals "gemini" "$result" "Single agent selected"
}

test_capability_weights_default() {
    echo -e "\n${CYAN}▶${NC} Test: Default capability weights sum to ~1.0"

    local sum
    sum=$(python3 -c "
import json
config = json.load(open('$CAPABILITIES_FILE'))
weights = config['capability_weights']['default']
print(f'{sum(weights.values()):.2f}')
" 2>/dev/null)

    assert_equals "1.00" "$sum" "Default weights sum to 1.0"
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Intelligent Agent Selection Test Suite (P16.4)     ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_capabilities_file_valid
    test_capability_scores_exist
    test_task_analysis_code_heavy
    test_task_analysis_architecture
    test_task_analysis_documentation
    test_agent_selection_code_to_qwen
    test_agent_selection_architecture_to_gemini
    test_agent_selection_fallback
    test_agent_selection_no_available_agents
    test_agent_selection_single_agent
    test_capability_weights_default

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
