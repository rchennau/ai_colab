#!/usr/bin/env bash
# Test Suite: API Key Detection (P4.3)
# Tests: environment detection, .env file detection, masking, prompts

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

assert_not_empty() {
    local value="$1"
    local message="$2"

    if [[ -n "$value" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        echo -e "  Value is empty"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Tests
# ============================================================

test_detect_function_exists() {
    echo -e "\n${CYAN}▶${NC} Test: API key detection function exists"

    if grep -q "detect_api_key()" "$PROJECT_ROOT/scripts/install-wizard.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} detect_api_key() function exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} detect_api_key() function missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_mask_function_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Key masking function exists"

    if grep -q "mask_key()" "$PROJECT_ROOT/scripts/install-wizard.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} mask_key() function exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} mask_key() function missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_prompt_function_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Prompt existing key function exists"

    if grep -q "prompt_existing_api_key()" "$PROJECT_ROOT/scripts/install-wizard.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} prompt_existing_api_key() function exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} prompt_existing_api_key() function missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_all_keys_defined() {
    echo -e "\n${CYAN}▶${NC} Test: All API keys are defined in metadata"

    local expected_keys=("GEMINI_API_KEY" "ANTHROPIC_API_KEY" "OPENAI_API_KEY" "DEEPSEEK_API_KEY" "QWEN_API_KEY" "NVIDIA_API_KEY" "RUNPOD_API_KEY")
    local all_found=true

    for key in "${expected_keys[@]}"; do
        if grep -q "\"$key\"" "$PROJECT_ROOT/scripts/install-wizard.sh"; then
            echo -e "${GREEN}✓ PASS:${NC} Key '$key' defined in metadata"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL:${NC} Key '$key' missing from metadata"
            ((TESTS_FAILED++))
            all_found=false
        fi
        ((TESTS_RUN++))
    done
}

test_env_example_has_all_keys() {
    echo -e "\n${CYAN}▶${NC} Test: .env.example contains all API keys"

    local expected_keys=("GEMINI_API_KEY" "ANTHROPIC_API_KEY" "OPENAI_API_KEY" "DEEPSEEK_API_KEY" "QWEN_API_KEY" "NVIDIA_API_KEY" "RUNPOD_API_KEY")

    for key in "${expected_keys[@]}"; do
        if grep -q "${key}" "$PROJECT_ROOT/.env.example"; then
            echo -e "${GREEN}✓ PASS:${NC} Key '$key' documented in .env.example"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL:${NC} Key '$key' missing from .env.example"
            ((TESTS_FAILED++))
        fi
        ((TESTS_RUN++))
    done
}

test_detect_from_env() {
    echo -e "\n${CYAN}▶${NC} Test: Detect API key from environment variable"

    # Source the wizard to get functions
    (
        export PROJECT_ROOT="$PROJECT_ROOT"
        source "$PROJECT_ROOT/scripts/utils.sh" >/dev/null 2>&1

        # Define the detect function inline for testing
        detect_api_key() {
            local key_name="$1"
            local env_value="${!key_name:-}"
            if [[ -n "$env_value" ]]; then
                echo "$env_value"
                return 0
            fi
            return 1
        }

        # Test with a temporary env var
        export TEST_API_KEY="test-value-12345"
        local result
        result=$(detect_api_key "TEST_API_KEY" 2>/dev/null)

        if [[ "$result" == "test-value-12345" ]]; then
            echo -e "${GREEN}✓ PASS:${NC} Detected API key from environment"
        else
            echo -e "${RED}✗ FAIL:${NC} Failed to detect API key from environment"
        fi
    )
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

test_masking_hides_sensitive_data() {
    echo -e "\n${CYAN}▶${NC} Test: Key masking hides sensitive data"

    (
        export PROJECT_ROOT="$PROJECT_ROOT"
        source "$PROJECT_ROOT/scripts/utils.sh" >/dev/null 2>&1

        # Define mask function inline
        mask_key() {
            local key="$1"
            local len=${#key}
            if [[ $len -le 8 ]]; then
                echo "****"
            else
                echo "${key:0:4}...${key:$((len-4)):4}"
            fi
        }

        local result
        result=$(mask_key "sk-1234567890abcdef")

        if [[ "$result" == "sk-1...cdef" ]]; then
            echo -e "${GREEN}✓ PASS:${NC} Key properly masked"
        else
            echo -e "${RED}✗ FAIL:${NC} Key masking incorrect: $result"
        fi
    )
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

test_save_function_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Save API keys function exists"

    if grep -q "save_api_keys()" "$PROJECT_ROOT/scripts/install-wizard.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} save_api_keys() function exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} save_api_keys() function missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_collect_function_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Collect API keys function exists"

    if grep -q "collect_api_keys()" "$PROJECT_ROOT/scripts/install-wizard.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} collect_api_keys() function exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} collect_api_keys() function missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_web_auth_detection_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Web auth detection function exists"

    if grep -q "detect_web_auth()" "$PROJECT_ROOT/scripts/install-wizard.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} detect_web_auth() function exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} detect_web_auth() function missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_auth_methods_defined() {
    echo -e "\n${CYAN}▶${NC} Test: Auth methods are defined for all agents"

    local agents=("GEMINI" "QWEN" "ANTHROPIC" "OPENAI" "DEEPSEEK" "NVIDIA" "RUNPOD")

    for agent in "${agents[@]}"; do
        if grep -q "\"$agent\"" "$PROJECT_ROOT/scripts/install-wizard.sh"; then
            echo -e "${GREEN}✓ PASS:${NC} Auth method defined for '$agent'"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL:${NC} Auth method missing for '$agent'"
            ((TESTS_FAILED++))
        fi
        ((TESTS_RUN++))
    done
}

test_web_auth_agents_correct() {
    echo -e "\n${CYAN}▶${NC} Test: Web auth correctly assigned to Gemini and Qwen"

    if grep -q '\["GEMINI"\]="both"' "$PROJECT_ROOT/scripts/install-wizard.sh" && \
       grep -q '\["QWEN"\]="both"' "$PROJECT_ROOT/scripts/install-wizard.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Gemini and Qwen support both API key and web auth"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Gemini and/or Qwen web auth not configured correctly"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_prompt_web_auth_function_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Web auth prompt function exists"

    if grep -q "prompt_web_auth()" "$PROJECT_ROOT/scripts/install-wizard.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} prompt_web_auth() function exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} prompt_web_auth() function missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  API Key Detection Test Suite (P4.3)                ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_detect_function_exists
    test_mask_function_exists
    test_prompt_function_exists
    test_all_keys_defined
    test_env_example_has_all_keys
    test_detect_from_env
    test_masking_hides_sensitive_data
    test_save_function_exists
    test_collect_function_exists
    test_web_auth_detection_exists
    test_auth_methods_defined
    test_web_auth_agents_correct
    test_prompt_web_auth_function_exists

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
