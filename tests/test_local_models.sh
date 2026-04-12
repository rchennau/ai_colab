#!/usr/bin/env bash
# Comprehensive Test Harness: Local LLM Support (P5.1)
# Tests: model manager, local models config, shell wrapper, integration, edge cases

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

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"

    if [[ "$haystack" != *"$needle"* ]]; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        echo -e "  Should NOT contain: '$needle'"
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
# Test Categories
# ============================================================

# -------------------------------------------------------
# Category 1: File & Structure Tests
# -------------------------------------------------------

test_files_exist() {
    echo -e "\n${CYAN}▶${NC} Test: All required files exist"

    assert_file_exists "$PROJECT_ROOT/config/local-models.json" "Local models config exists"
    assert_file_exists "$PROJECT_ROOT/scripts/model-manager.py" "Model manager exists"
    assert_file_exists "$PROJECT_ROOT/scripts/local-models.sh" "Local models shell wrapper exists"
}

test_scripts_executable() {
    echo -e "\n${CYAN}▶${NC} Test: Scripts are executable"

    assert_executable "$PROJECT_ROOT/scripts/local-models.sh" "Shell wrapper is executable"
}

test_python_syntax() {
    echo -e "\n${CYAN}▶${NC} Test: Python syntax is valid"

    if python3 -m py_compile "$PROJECT_ROOT/scripts/model-manager.py" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Python syntax is valid"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Python syntax error"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# -------------------------------------------------------
# Category 2: Configuration Tests
# -------------------------------------------------------

test_config_valid_json() {
    echo -e "\n${CYAN}▶${NC} Test: Config is valid JSON"

    if python3 -c "import json; json.load(open('$PROJECT_ROOT/config/local-models.json'))" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Config is valid JSON"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Config is not valid JSON"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_config_has_required_sections() {
    echo -e "\n${CYAN}▶${NC} Test: Config has required sections"

    local sections
    sections=$(python3 -c "
import json
with open('$PROJECT_ROOT/config/local-models.json') as f:
    config = json.load(f)
required = ['runtimes', 'models', 'defaults']
missing = [s for s in required if s not in config]
print(' '.join(missing) if missing else 'ok')
" 2>/dev/null)

    if [[ "$sections" == "ok" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Config has all required sections"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Config missing sections: $sections"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_config_model_fields() {
    echo -e "\n${CYAN}▶${NC} Test: All models have required fields"

    local missing_fields
    missing_fields=$(python3 -c "
import json
with open('$PROJECT_ROOT/config/local-models.json') as f:
    config = json.load(f)
required_fields = ['display_name', 'runtime', 'size_gb', 'capabilities', 'min_ram_gb', 'download_url']
missing = []
for model_id, model_info in config.get('models', {}).items():
    for field in required_fields:
        if field not in model_info:
            missing.append(f'{model_id}.{field}')
print(' '.join(missing) if missing else 'ok')
" 2>/dev/null)

    if [[ "$missing_fields" == "ok" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} All models have required fields"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Models missing fields: $missing_fields"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_config_runtime_fields() {
    echo -e "\n${CYAN}▶${NC} Test: All runtimes have required fields"

    local missing_fields
    missing_fields=$(python3 -c "
import json
with open('$PROJECT_ROOT/config/local-models.json') as f:
    config = json.load(f)
required_fields = ['display_name', 'install_command', 'health_check']
missing = []
for runtime_id, runtime_info in config.get('runtimes', {}).items():
    for field in required_fields:
        if field not in runtime_info:
            missing.append(f'{runtime_id}.{field}')
print(' '.join(missing) if missing else 'ok')
" 2>/dev/null)

    if [[ "$missing_fields" == "ok" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} All runtimes have required fields"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Runtimes missing fields: $missing_fields"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_config_defaults() {
    echo -e "\n${CYAN}▶${NC} Test: Config has defaults section"

    local has_defaults
    has_defaults=$(python3 -c "
import json
with open('$PROJECT_ROOT/config/local-models.json') as f:
    config = json.load(f)
defaults = config.get('defaults', {})
required = ['default_runtime', 'recommended_model']
missing = [k for k in required if k not in defaults]
print(' '.join(missing) if missing else 'ok')
" 2>/dev/null)

    if [[ "$has_defaults" == "ok" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Config has valid defaults"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Config defaults missing: $has_defaults"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# -------------------------------------------------------
# Category 3: Command Tests
# -------------------------------------------------------

test_list_command() {
    echo -e "\n${CYAN}▶${NC} Test: List command shows models"

    local output
    output=$(python3 "$PROJECT_ROOT/scripts/model-manager.py" list 2>&1)

    if echo "$output" | grep -q "Available Models\|qwen2.5-coder\|llama3.1"; then
        echo -e "${GREEN}✓ PASS:${NC} List command works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} List command failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_list_command_with_runtime_filter() {
    echo -e "\n${CYAN}▶${NC} Test: List command filters by runtime"

    local output
    output=$(python3 "$PROJECT_ROOT/scripts/model-manager.py" list --runtime ollama 2>&1)

    if echo "$output" | grep -q "ollama\|qwen2.5-coder\|llama3.1"; then
        echo -e "${GREEN}✓ PASS:${NC} List command filters by runtime"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} List command runtime filter failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_recommend_command_coding() {
    echo -e "\n${CYAN}▶${NC} Test: Recommend command for coding task"

    local output
    output=$(python3 "$PROJECT_ROOT/scripts/model-manager.py" recommend --task coding 2>&1)

    if echo "$output" | grep -q "Recommended\|qwen2.5-coder\|coding"; then
        echo -e "${GREEN}✓ PASS:${NC} Recommend command works for coding"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Recommend command failed for coding"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_recommend_command_reasoning() {
    echo -e "\n${CYAN}▶${NC} Test: Recommend command for reasoning task"

    local output
    output=$(python3 "$PROJECT_ROOT/scripts/model-manager.py" recommend --task reasoning 2>&1)

    if echo "$output" | grep -q "Recommended\|model"; then
        echo -e "${GREEN}✓ PASS:${NC} Recommend command works for reasoning"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Recommend command failed for reasoning"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_recommend_command_documentation() {
    echo -e "\n${CYAN}▶${NC} Test: Recommend command for documentation task"

    local output
    output=$(python3 "$PROJECT_ROOT/scripts/model-manager.py" recommend --task documentation 2>&1)

    if echo "$output" | grep -q "Recommended\|model"; then
        echo -e "${GREEN}✓ PASS:${NC} Recommend command works for documentation"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Recommend command failed for documentation"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_status_command() {
    echo -e "\n${CYAN}▶${NC} Test: Status command returns JSON"

    local output
    output=$(python3 "$PROJECT_ROOT/scripts/model-manager.py" status 2>&1)

    if echo "$output" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Status command returns valid JSON"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Status command does not return valid JSON"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_health_command() {
    echo -e "\n${CYAN}▶${NC} Test: Health command returns runtime status"

    local output
    output=$(python3 "$PROJECT_ROOT/scripts/model-manager.py" health 2>&1)

    if echo "$output" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Health command returns valid JSON"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Health command does not return valid JSON"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# -------------------------------------------------------
# Category 4: Shell Wrapper Tests
# -------------------------------------------------------

test_shell_help() {
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

test_shell_list() {
    echo -e "\n${CYAN}▶${NC} Test: Shell wrapper list command"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/local-models.sh" list 2>&1)

    if echo "$output" | grep -q "Available Models\|qwen2.5-coder"; then
        echo -e "${GREEN}✓ PASS:${NC} Shell wrapper list works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Shell wrapper list failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_shell_health() {
    echo -e "\n${CYAN}▶${NC} Test: Shell wrapper health command"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/local-models.sh" health 2>&1)

    if echo "$output" | grep -q "ollama\|llamacpp\|vllm_local"; then
        echo -e "${GREEN}✓ PASS:${NC} Shell wrapper health works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Shell wrapper health failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# -------------------------------------------------------
# Category 5: Edge Cases & Error Handling
# -------------------------------------------------------

test_recommend_unknown_task() {
    echo -e "\n${CYAN}▶${NC} Test: Recommend command handles unknown task"

    local output
    output=$(python3 "$PROJECT_ROOT/scripts/model-manager.py" recommend --task unknown_task_xyz 2>&1)

    # Should return default model or no recommendation, not crash
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Recommend handles unknown task gracefully"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Recommend crashed on unknown task"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_download_missing_model() {
    echo -e "\n${CYAN}▶${NC} Test: Download command handles missing model"

    local output
    output=$(python3 "$PROJECT_ROOT/scripts/model-manager.py" download --model nonexistent_model_123 2>&1)

    if echo "$output" | grep -qi "error\|not found"; then
        echo -e "${GREEN}✓ PASS:${NC} Download handles missing model correctly"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Download did not handle missing model"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_list_unknown_runtime() {
    echo -e "\n${CYAN}▶${NC} Test: List command handles unknown runtime"

    local output
    output=$(python3 "$PROJECT_ROOT/scripts/model-manager.py" list --runtime unknown_runtime 2>&1)

    # Should return empty list, not crash
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ PASS:${NC} List handles unknown runtime gracefully"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} List crashed on unknown runtime"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_shell_missing_model_arg() {
    echo -e "\n${CYAN}▶${NC} Test: Shell download without model arg"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/local-models.sh" download 2>&1 || true)

    if echo "$output" | grep -qi "error\|required\|model"; then
        echo -e "${GREEN}✓ PASS:${NC} Shell download validates model argument"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Shell download does not validate model argument"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_shell_missing_task_arg() {
    echo -e "\n${CYAN}▶${NC} Test: Shell recommend without task arg"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/local-models.sh" recommend 2>&1 || true)

    if echo "$output" | grep -qi "error\|required\|task"; then
        echo -e "${GREEN}✓ PASS:${NC} Shell recommend validates task argument"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Shell recommend does not validate task argument"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# -------------------------------------------------------
# Category 6: Integration Tests
# -------------------------------------------------------

test_model_count_consistency() {
    echo -e "\n${CYAN}▶${NC} Test: Model count matches config"

    local config_count list_count
    config_count=$(python3 -c "
import json
with open('$PROJECT_ROOT/config/local-models.json') as f:
    config = json.load(f)
print(len(config.get('models', {})))
" 2>/dev/null)

    list_count=$(python3 "$PROJECT_ROOT/scripts/model-manager.py" list 2>&1 | grep -c "qwen2.5-coder\|llama3.1\|mistral\|deepseek-coder\|codellama\|phi3" || echo "0")

    if [[ "$config_count" -gt 0 && "$list_count" -ge "$config_count" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Model count consistent ($config_count in config, $list_count listed)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Model count inconsistent ($config_count in config, $list_count listed)"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_recommend_returns_valid_model() {
    echo -e "\n${CYAN}▶${NC} Test: Recommend returns valid model ID"

    local output
    output=$(python3 "$PROJECT_ROOT/scripts/model-manager.py" recommend --task coding 2>&1)

    # Extract model ID and verify it exists in config
    local model_id
    model_id=$(echo "$output" | grep -o "ID: [a-zA-Z0-9._-]*" | head -1 | sed 's/ID: //')

    if [[ -n "$model_id" ]]; then
        local exists
        exists=$(python3 -c "
import json
with open('$PROJECT_ROOT/config/local-models.json') as f:
    config = json.load(f)
print('yes' if '$model_id' in config.get('models', {}) else 'no')
" 2>/dev/null)

        if [[ "$exists" == "yes" ]]; then
            echo -e "${GREEN}✓ PASS:${NC} Recommend returns valid model ID ($model_id)"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL:${NC} Recommend returns invalid model ID ($model_id)"
            ((TESTS_FAILED++))
        fi
    else
        echo -e "${RED}✗ FAIL:${NC} Recommend did not return model ID"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_health_returns_all_runtimes() {
    echo -e "\n${CYAN}▶${NC} Test: Health returns all configured runtimes"

    local output
    output=$(python3 "$PROJECT_ROOT/scripts/model-manager.py" health 2>&1)

    local runtime_count
    runtime_count=$(echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(len(data))
" 2>/dev/null)

    if [[ "$runtime_count" -ge 3 ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Health returns $runtime_count runtimes"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Health returns only $runtime_count runtimes"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Local LLM Support Test Harness (P5.1)              ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    # Category 1: File & Structure Tests
    test_files_exist
    test_scripts_executable
    test_python_syntax

    # Category 2: Configuration Tests
    test_config_valid_json
    test_config_has_required_sections
    test_config_model_fields
    test_config_runtime_fields
    test_config_defaults

    # Category 3: Command Tests
    test_list_command
    test_list_command_with_runtime_filter
    test_recommend_command_coding
    test_recommend_command_reasoning
    test_recommend_command_documentation
    test_status_command
    test_health_command

    # Category 4: Shell Wrapper Tests
    test_shell_help
    test_shell_list
    test_shell_health

    # Category 5: Edge Cases & Error Handling
    test_recommend_unknown_task
    test_download_missing_model
    test_list_unknown_runtime
    test_shell_missing_model_arg
    test_shell_missing_task_arg

    # Category 6: Integration Tests
    test_model_count_consistency
    test_recommend_returns_valid_model
    test_health_returns_all_runtimes

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
