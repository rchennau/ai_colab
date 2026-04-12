#!/usr/bin/env bash
# Test Suite: Local LLM Support (P5.1)
# Tests: model manager, local models config, shell wrapper

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

test_local_model_files_exist() {
    echo -e "\n${CYAN}▶${NC} Test: Local model files exist"

    assert_file_exists "$PROJECT_ROOT/config/local-models.json" "Local models config exists"
    assert_file_exists "$PROJECT_ROOT/scripts/model-manager.py" "Model manager exists"
    assert_file_exists "$PROJECT_ROOT/scripts/local-models.sh" "Local models shell wrapper exists"
}

test_local_model_scripts_executable() {
    echo -e "\n${CYAN}▶${NC} Test: Local model scripts are executable"

    assert_executable "$PROJECT_ROOT/scripts/local-models.sh" "Shell wrapper is executable"
}

test_model_manager_syntax() {
    echo -e "\n${CYAN}▶${NC} Test: Model manager Python syntax is valid"

    if python3 -m py_compile "$PROJECT_ROOT/scripts/model-manager.py" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Python syntax is valid"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Python syntax error"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_local_models_config_valid_json() {
    echo -e "\n${CYAN}▶${NC} Test: Local models config is valid JSON"

    if python3 -c "import json; json.load(open('$PROJECT_ROOT/config/local-models.json'))" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Local models config is valid JSON"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Local models config is not valid JSON"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_config_has_models() {
    echo -e "\n${CYAN}▶${NC} Test: Config has model definitions"

    local model_count
    model_count=$(python3 -c "
import json
with open('$PROJECT_ROOT/config/local-models.json') as f:
    config = json.load(f)
print(len(config.get('models', {})))
" 2>/dev/null)

    if [[ "$model_count" -gt 0 ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Config has $model_count model(s)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Config has no models"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_config_has_runtimes() {
    echo -e "\n${CYAN}▶${NC} Test: Config has runtime definitions"

    local runtime_count
    runtime_count=$(python3 -c "
import json
with open('$PROJECT_ROOT/config/local-models.json') as f:
    config = json.load(f)
print(len(config.get('runtimes', {})))
" 2>/dev/null)

    if [[ "$runtime_count" -ge 2 ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Config has $runtime_count runtime(s)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Config has insufficient runtimes"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_model_list_command() {
    echo -e "\n${CYAN}▶${NC} Test: Model list command works"

    local output
    output=$(python3 "$PROJECT_ROOT/scripts/model-manager.py" list 2>&1)

    if echo "$output" | grep -q "Available Models\|qwen2.5-coder\|llama3.1"; then
        echo -e "${GREEN}✓ PASS:${NC} Model list command works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Model list command failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_model_recommend_command() {
    echo -e "\n${CYAN}▶${NC} Test: Model recommend command works"

    local output
    output=$(python3 "$PROJECT_ROOT/scripts/model-manager.py" recommend --task coding 2>&1)

    if echo "$output" | grep -q "Recommended\|qwen2.5-coder\|coding"; then
        echo -e "${GREEN}✓ PASS:${NC} Model recommend command works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Model recommend command failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_model_status_command() {
    echo -e "\n${CYAN}▶${NC} Test: Model status command works"

    local output
    output=$(python3 "$PROJECT_ROOT/scripts/model-manager.py" status 2>&1)

    if echo "$output" | grep -q "health\|available_models\|runtimes"; then
        echo -e "${GREEN}✓ PASS:${NC} Model status command works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Model status command failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_model_health_command() {
    echo -e "\n${CYAN}▶${NC} Test: Model health command works"

    local output
    output=$(python3 "$PROJECT_ROOT/scripts/model-manager.py" health 2>&1)

    if echo "$output" | grep -q "ollama\|llamacpp\|vllm_local"; then
        echo -e "${GREEN}✓ PASS:${NC} Model health command works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Model health command failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_shell_wrapper_help() {
    echo -e "\n${CYAN}▶${NC} Test: Shell wrapper help works"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/local-models.sh" --help 2>&1)

    if echo "$output" | grep -q "Usage\|--model\|--task\|--runtime"; then
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
    echo -e "${BLUE}║  Local LLM Support Test Suite (P5.1)                ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_local_model_files_exist
    test_local_model_scripts_executable
    test_model_manager_syntax
    test_local_models_config_valid_json
    test_config_has_models
    test_config_has_runtimes
    test_model_list_command
    test_model_recommend_command
    test_model_status_command
    test_model_health_command
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
