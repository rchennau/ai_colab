#!/usr/bin/env bash
# Test Suite: Agent Benchmarking Framework (P4.5)
# Tests: task definitions, runner, report generation

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

# ============================================================
# Tests
# ============================================================

test_benchmark_files_exist() {
    echo -e "\n${CYAN}▶${NC} Test: Benchmark files exist"

    assert_file_exists "$PROJECT_ROOT/config/benchmark-tasks.json" "Task definitions file exists"
    assert_file_exists "$PROJECT_ROOT/scripts/benchmark-runner.py" "Benchmark runner exists"
    assert_file_exists "$PROJECT_ROOT/scripts/agent-benchmark.sh" "Benchmark shell wrapper exists"
    assert_file_exists "$PROJECT_ROOT/scripts/benchmark-report.sh" "Benchmark report generator exists"
}

test_benchmark_scripts_executable() {
    echo -e "\n${CYAN}▶${NC} Test: Benchmark scripts are executable"

    assert_executable "$PROJECT_ROOT/scripts/agent-benchmark.sh" "Shell wrapper is executable"
    assert_executable "$PROJECT_ROOT/scripts/benchmark-report.sh" "Report generator is executable"
}

test_tasks_file_valid_json() {
    echo -e "\n${CYAN}▶${NC} Test: Tasks file is valid JSON"

    if python3 -c "import json; json.load(open('$PROJECT_ROOT/config/benchmark-tasks.json'))" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Tasks file is valid JSON"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Tasks file is not valid JSON"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_tasks_have_all_categories() {
    echo -e "\n${CYAN}▶${NC} Test: Tasks cover all capability dimensions"

    local categories
    categories=$(python3 -c "
import json
with open('$PROJECT_ROOT/config/benchmark-tasks.json') as f:
    config = json.load(f)
cats = set()
for task in config.get('tasks', {}).values():
    cats.add(task.get('category', 'unknown'))
print(' '.join(sorted(cats)))
" 2>/dev/null)

    local expected_categories="architecture coding documentation reasoning"

    for cat in $expected_categories; do
        if echo "$categories" | grep -q "$cat"; then
            echo -e "${GREEN}✓ PASS:${NC} Category '$cat' has tasks"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL:${NC} Category '$cat' missing"
            ((TESTS_FAILED++))
        fi
        ((TESTS_RUN++))
    done
}

test_tasks_have_evaluation_criteria() {
    echo -e "\n${CYAN}▶${NC} Test: All tasks have evaluation criteria"

    local tasks_without_criteria
    tasks_without_criteria=$(python3 -c "
import json
with open('$PROJECT_ROOT/config/benchmark-tasks.json') as f:
    config = json.load(f)
missing = []
for task_id, task in config.get('tasks', {}).items():
    eval_config = task.get('evaluation', {})
    if not eval_config.get('criteria'):
        missing.append(task_id)
print(' '.join(missing))
" 2>/dev/null)

    if [[ -z "$tasks_without_criteria" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} All tasks have evaluation criteria"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Tasks missing criteria: $tasks_without_criteria"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_runner_can_list_tasks() {
    echo -e "\n${CYAN}▶${NC} Test: Benchmark runner can list tasks"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/agent-benchmark.sh" --list-tasks 2>&1)

    if echo "$output" | grep -q "coding\|reasoning\|architecture\|documentation"; then
        echo -e "${GREEN}✓ PASS:${NC} Runner lists task categories"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Runner does not list task categories"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_runner_validates_agent() {
    echo -e "\n${CYAN}▶${NC} Test: Runner validates agent argument"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/agent-benchmark.sh" 2>&1 || true)

    if echo "$output" | grep -qi "agent.*required\|usage\|help"; then
        echo -e "${GREEN}✓ PASS:${NC} Runner validates agent argument"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Runner does not validate agent argument"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_runner_help_works() {
    echo -e "\n${CYAN}▶${NC} Test: Runner help works"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/agent-benchmark.sh" --help 2>&1)

    if echo "$output" | grep -q "Usage\|--agent\|--tasks"; then
        echo -e "${GREEN}✓ PASS:${NC} Runner help works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Runner help does not work"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_report_generator_help() {
    echo -e "\n${CYAN}▶${NC} Test: Report generator help works"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/benchmark-report.sh" --help 2>&1)

    if echo "$output" | grep -q "Usage\|--compare"; then
        echo -e "${GREEN}✓ PASS:${NC} Report generator help works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Report generator help does not work"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_runner_python_syntax() {
    echo -e "\n${CYAN}▶${NC} Test: Benchmark runner Python syntax is valid"

    if python3 -m py_compile "$PROJECT_ROOT/scripts/benchmark-runner.py" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Python syntax is valid"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Python syntax error"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Agent Benchmarking Test Suite (P4.5)               ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_benchmark_files_exist
    test_benchmark_scripts_executable
    test_tasks_file_valid_json
    test_tasks_have_all_categories
    test_tasks_have_evaluation_criteria
    test_runner_can_list_tasks
    test_runner_validates_agent
    test_runner_help_works
    test_report_generator_help
    test_runner_python_syntax

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
