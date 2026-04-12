#!/usr/bin/env bash
# Test Suite: Structured Communication Protocol (P6.1)
# Tests: protocol encoder, decoder, validation, human-readable summaries

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

assert_valid_json() {
    local json="$1"
    local message="$2"

    if echo "$json" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message - invalid JSON"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Tests
# ============================================================

test_protocol_files_exist() {
    echo -e "\n${CYAN}▶${NC} Test: Protocol files exist"

    assert_file_exists "$PROJECT_ROOT/config/message-protocol.json" "Protocol schema exists"
    assert_file_exists "$PROJECT_ROOT/scripts/protocol-encoder.sh" "Protocol encoder exists"
    assert_file_exists "$PROJECT_ROOT/scripts/protocol-decoder.py" "Protocol decoder exists"
}

test_protocol_scripts_executable() {
    echo -e "\n${CYAN}▶${NC} Test: Protocol scripts are executable"

    assert_executable "$PROJECT_ROOT/scripts/protocol-encoder.sh" "Encoder is executable"
    assert_executable "$PROJECT_ROOT/scripts/protocol-decoder.py" "Decoder is executable"
}

test_protocol_schema_valid_json() {
    echo -e "\n${CYAN}▶${NC} Test: Protocol schema is valid JSON"

    if python3 -c "import json; json.load(open('$PROJECT_ROOT/config/message-protocol.json'))" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Protocol schema is valid JSON"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Protocol schema is not valid JSON"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_protocol_schema_has_message_types() {
    echo -e "\n${CYAN}▶${NC} Test: Protocol schema has message types"

    local msg_types
    msg_types=$(python3 -c "
import json
with open('$PROJECT_ROOT/config/message-protocol.json') as f:
    schema = json.load(f)
types = list(schema.get('message_types', {}).keys())
print(' '.join(types))
" 2>/dev/null)

    for expected_type in status heartbeat request response error complete; do
        if echo "$msg_types" | grep -q "$expected_type"; then
            echo -e "${GREEN}✓ PASS:${NC} Schema has '$expected_type' message type"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL:${NC} Schema missing '$expected_type' message type"
            ((TESTS_FAILED++))
        fi
        ((TESTS_RUN++))
    done
}

test_encoder_status() {
    echo -e "\n${CYAN}▶${NC} Test: Encoder creates valid status message"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/protocol-encoder.sh" status \
        --agent test_agent \
        --track test-track \
        --pct 45 \
        --step "coding endpoints" \
        --phase coding \
        --eta 1800 2>&1)

    assert_valid_json "$output" "Status message is valid JSON"

    # Check required fields
    assert_contains "$output" '"t":"status"' "Message type is status"
    assert_contains "$output" '"a":"test_agent"' "Agent name correct"
    assert_contains "$output" '"track":"test-track"' "Track slug correct"
    assert_contains "$output" '"pct":45' "Progress percentage correct"
}

test_encoder_heartbeat() {
    echo -e "\n${CYAN}▶${NC} Test: Encoder creates valid heartbeat message"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/protocol-encoder.sh" heartbeat \
        --agent gemini \
        --latency 150 \
        --load 0.3 2>&1)

    assert_valid_json "$output" "Heartbeat message is valid JSON"
    assert_contains "$output" '"t":"heartbeat"' "Message type is heartbeat"
    assert_contains "$output" '"latency_ms":150' "Latency correct"
}

test_encoder_error() {
    echo -e "\n${CYAN}▶${NC} Test: Encoder creates valid error message"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/protocol-encoder.sh" error \
        --agent qwen \
        --track my-track \
        --err compilation_failed \
        --detail "Syntax error in handlers.py" \
        --recoverable true \
        --retry 2 2>&1)

    assert_valid_json "$output" "Error message is valid JSON"
    assert_contains "$output" '"t":"error"' "Message type is error"
    assert_contains "$output" '"err":"compilation_failed"' "Error code correct"
}

test_encoder_complete() {
    echo -e "\n${CYAN}▶${NC} Test: Encoder creates valid complete message"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/protocol-encoder.sh" complete \
        --agent claude \
        --track write-docs \
        --detail "All sections complete" 2>&1)

    assert_valid_json "$output" "Complete message is valid JSON"
    assert_contains "$output" '"t":"complete"' "Message type is complete"
    assert_contains "$output" '"pct":100' "Progress is 100%"
}

test_decoder_summary_status() {
    echo -e "\n${CYAN}▶${NC} Test: Decoder generates summary for status message"

    local summary
    summary=$(python3 "$PROJECT_ROOT/scripts/protocol-decoder.py" --summary \
        '{"v":1,"t":"status","a":"gemini","track":"implement-api","pct":45,"step":"writing endpoints","eta":1800}' 2>&1)

    assert_contains "$summary" "Gemini" "Agent name displayed"
    assert_contains "$summary" "45%" "Progress displayed"
    assert_contains "$summary" "implement-api" "Track displayed"
    assert_contains "$summary" "writing endpoints" "Step displayed"
}

test_decoder_summary_error() {
    echo -e "\n${CYAN}▶${NC} Test: Decoder generates summary for error message"

    local summary
    summary=$(python3 "$PROJECT_ROOT/scripts/protocol-decoder.py" --summary \
        '{"v":1,"t":"error","a":"qwen","track":"fix-bug","err":"test_failed","detail":"3 tests failing"}' 2>&1)

    assert_contains "$summary" "Qwen" "Agent name displayed"
    assert_contains "$summary" "test_failed" "Error code displayed"
    assert_contains "$summary" "3 tests failing" "Detail displayed"
}

test_decoder_summary_complete() {
    echo -e "\n${CYAN}▶${NC} Test: Decoder generates summary for complete message"

    local summary
    summary=$(python3 "$PROJECT_ROOT/scripts/protocol-decoder.py" --summary \
        '{"v":1,"t":"complete","a":"claude","track":"write-docs","detail":"All sections complete"}' 2>&1)

    assert_contains "$summary" "Claude" "Agent name displayed"
    assert_contains "$summary" "completed" "Completion indicated"
}

test_decoder_validation_valid() {
    echo -e "\n${CYAN}▶${NC} Test: Decoder validates valid message"

    local output
    output=$(python3 "$PROJECT_ROOT/scripts/protocol-decoder.py" --validate \
        '{"v":1,"t":"status","a":"gemini","ts":1712876400,"track":"test","pct":50,"step":"coding"}' 2>&1)

    if echo "$output" | grep -q "Valid"; then
        echo -e "${GREEN}✓ PASS:${NC} Valid message accepted"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Valid message rejected: $output"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_decoder_validation_invalid() {
    echo -e "\n${CYAN}▶${NC} Test: Decoder rejects invalid message"

    local output
    output=$(python3 "$PROJECT_ROOT/scripts/protocol-decoder.py" --validate \
        '{"v":1,"t":"status","a":"gemini"}' 2>&1 || true)

    if echo "$output" | grep -q "Invalid\|Missing"; then
        echo -e "${GREEN}✓ PASS:${NC} Invalid message rejected"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Invalid message accepted: $output"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_decoder_tmux_status_line() {
    echo -e "\n${CYAN}▶${NC} Test: Decoder generates tmux status line"

    local status_line
    status_line=$(python3 "$PROJECT_ROOT/scripts/protocol-decoder.py" --status-line \
        '[{"t":"status","a":"gemini","pct":45,"phase":"coding"},{"t":"status","a":"qwen","pct":100},{"t":"error","a":"claude"}]' 2>&1)

    assert_contains "$status_line" "gemini" "Gemini in status line"
    assert_contains "$status_line" "qwen" "Qwen in status line"
    assert_contains "$status_line" "claude" "Claude in status line"
}

test_encoder_verbose_request() {
    echo -e "\n${CYAN}▶${NC} Test: Encoder creates verbose request"

    local output
    output=$(bash "$PROJECT_ROOT/scripts/protocol-encoder.sh" verbose gemini 5 2>&1)

    assert_valid_json "$output" "Verbose request is valid JSON"
    assert_contains "$output" '"mode":"verbose"' "Mode is verbose"
    assert_contains "$output" '"agent":"gemini"' "Target agent correct"
    assert_contains "$output" '"count":5' "Message count correct"
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Communication Protocol Test Suite (P6.1)           ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_protocol_files_exist
    test_protocol_scripts_executable
    test_protocol_schema_valid_json
    test_protocol_schema_has_message_types
    test_encoder_status
    test_encoder_heartbeat
    test_encoder_error
    test_encoder_complete
    test_decoder_summary_status
    test_decoder_summary_error
    test_decoder_summary_complete
    test_decoder_validation_valid
    test_decoder_validation_invalid
    test_decoder_tmux_status_line
    test_encoder_verbose_request

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
