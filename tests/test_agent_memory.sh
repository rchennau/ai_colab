#!/usr/bin/env bash
# Test Suite: Agent Memory & Persistent Context (P5.2)
# Tests: memory manager, context window, compression, shell wrapper

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

# Clean up test memory DB
cleanup_test_memory() {
    rm -rf "$PROJECT_ROOT/.ai-colab/memory" 2>/dev/null || true
}

# ============================================================
# Tests
# ============================================================

test_memory_files_exist() {
    echo -e "\n${CYAN}▶${NC} Test: Memory files exist"

    assert_file_exists "$PROJECT_ROOT/scripts/memory-manager.py" "Memory manager exists"
    assert_file_exists "$PROJECT_ROOT/scripts/agent-memory.sh" "Memory shell wrapper exists"
    assert_file_exists "$PROJECT_ROOT/config/memory-config.json" "Memory config exists"
}

test_memory_scripts_executable() {
    echo -e "\n${CYAN}▶${NC} Test: Memory scripts are executable"

    assert_executable "$PROJECT_ROOT/scripts/agent-memory.sh" "Shell wrapper is executable"
}

test_memory_manager_syntax() {
    echo -e "\n${CYAN}▶${NC} Test: Memory manager Python syntax is valid"

    if python3 -m py_compile "$PROJECT_ROOT/scripts/memory-manager.py" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Python syntax is valid"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Python syntax error"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_memory_config_valid_json() {
    echo -e "\n${CYAN}▶${NC} Test: Memory config is valid JSON"

    if python3 -c "import json; json.load(open('$PROJECT_ROOT/config/memory-config.json'))" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Config is valid JSON"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Config is not valid JSON"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_save_and_load_message() {
    echo -e "\n${CYAN}▶${NC} Test: Save and load message"

    cleanup_test_memory

    # Save a message
    python3 "$PROJECT_ROOT/scripts/memory-manager.py" save \
        --agent test_agent \
        --role user \
        --message "Hello, world!" 2>&1

    # Load context
    local context
    context=$(python3 "$PROJECT_ROOT/scripts/memory-manager.py" load --agent test_agent 2>&1)

    if echo "$context" | grep -q "Hello, world!"; then
        echo -e "${GREEN}✓ PASS:${NC} Message saved and loaded correctly"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Message not loaded correctly"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    cleanup_test_memory
}

test_save_multiple_messages() {
    echo -e "\n${CYAN}▶${NC} Test: Save multiple messages"

    cleanup_test_memory

    # Save multiple messages
    python3 "$PROJECT_ROOT/scripts/memory-manager.py" save \
        --agent test_agent \
        --role user \
        --message "Message 1" 2>&1

    python3 "$PROJECT_ROOT/scripts/memory-manager.py" save \
        --agent test_agent \
        --role assistant \
        --message "Response 1" 2>&1

    python3 "$PROJECT_ROOT/scripts/memory-manager.py" save \
        --agent test_agent \
        --role user \
        --message "Message 2" 2>&1

    # Load context
    local context
    context=$(python3 "$PROJECT_ROOT/scripts/memory-manager.py" load --agent test_agent 2>&1)

    if echo "$context" | grep -q "Message 1" && \
       echo "$context" | grep -q "Response 1" && \
       echo "$context" | grep -q "Message 2"; then
        echo -e "${GREEN}✓ PASS:${NC} All messages saved and loaded"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Not all messages loaded correctly"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    cleanup_test_memory
}

test_memory_status() {
    echo -e "\n${CYAN}▶${NC} Test: Memory status command"

    cleanup_test_memory

    # Save a message
    python3 "$PROJECT_ROOT/scripts/memory-manager.py" save \
        --agent test_agent \
        --role user \
        --message "Test message" 2>&1

    # Get status
    local status
    status=$(python3 "$PROJECT_ROOT/scripts/memory-manager.py" status --agent test_agent 2>&1)

    if echo "$status" | grep -q "message_count" && echo "$status" | grep -q "test_agent"; then
        echo -e "${GREEN}✓ PASS:${NC} Status command works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Status command failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    cleanup_test_memory
}

test_memory_clear() {
    echo -e "\n${CYAN}▶${NC} Test: Memory clear command"

    cleanup_test_memory

    # Save a message
    python3 "$PROJECT_ROOT/scripts/memory-manager.py" save \
        --agent test_agent \
        --role user \
        --message "Test message" 2>&1

    # Clear memory
    python3 "$PROJECT_ROOT/scripts/memory-manager.py" clear --agent test_agent 2>&1

    # Check status
    local status
    status=$(python3 "$PROJECT_ROOT/scripts/memory-manager.py" status --agent test_agent 2>&1)

    if echo "$status" | grep -q '"message_count": 0'; then
        echo -e "${GREEN}✓ PASS:${NC} Memory cleared successfully"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Memory not cleared"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    cleanup_test_memory
}

test_context_window_limit() {
    echo -e "\n${CYAN}▶${NC} Test: Context window respects max-messages limit"

    cleanup_test_memory

    # Save 5 messages
    for i in {1..5}; do
        python3 "$PROJECT_ROOT/scripts/memory-manager.py" save \
            --agent test_agent \
            --role user \
            --message "Message $i" 2>&1
    done

    # Load with max-messages=3
    local context
    context=$(python3 "$PROJECT_ROOT/scripts/memory-manager.py" load \
        --agent test_agent \
        --max-messages 3 2>&1)

    # Count messages in context (rough check)
    local message_count
    message_count=$(echo "$context" | grep -c '"role"' || echo "0")

    if [[ $message_count -le 3 ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Context window respects limit ($message_count messages)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Context window exceeds limit ($message_count messages)"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    cleanup_test_memory
}

test_shell_wrapper_help() {
    echo -e "\n${CYAN}▶${NC} Test: Shell wrapper help works"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/agent-memory.sh" --help 2>&1)

    if echo "$output" | grep -q "Usage\|--agent\|--role"; then
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
    echo -e "${BLUE}║  Agent Memory Test Suite (P5.2)                     ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_memory_files_exist
    test_memory_scripts_executable
    test_memory_manager_syntax
    test_memory_config_valid_json
    test_save_and_load_message
    test_save_multiple_messages
    test_memory_status
    test_memory_clear
    test_context_window_limit
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
