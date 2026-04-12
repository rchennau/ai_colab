#!/usr/bin/env bash
# Test Suite: Conductor Protocol Handler (P6.3)
# Tests: protocol message parsing, blackboard updates, error handling

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

test_handler_file_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Protocol handler exists"

    if [[ -f "$PROJECT_ROOT/scripts/protocol-handler.py" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Protocol handler file exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Protocol handler file missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_handler_syntax() {
    echo -e "\n${CYAN}▶${NC} Test: Protocol handler syntax"

    if python3 -m py_compile "$PROJECT_ROOT/scripts/protocol-handler.py" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS:${NC} Python syntax is valid"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Python syntax error"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_status_message_parsed() {
    echo -e "\n${CYAN}▶${NC} Test: Status message parsed correctly"

    local msg='{"v":1,"t":"status","a":"gemini","track":"my-track","pct":45,"step":"coding","phase":"coding","eta":1800}'
    local output
    output=$(python3 -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/scripts')
from importlib.machinery import SourceFileLoader
handler = SourceFileLoader('handler', '$PROJECT_ROOT/scripts/protocol-handler.py').load_module()
msg = handler.parse_protocol_message('$msg')
print(f\"{msg.get('t')}|{msg.get('a')}|{msg.get('pct')}|{msg.get('track')}\")
" 2>/dev/null)

    assert_equals "status|gemini|45|my-track" "$output" "Status message parsed"
}

test_error_message_parsed() {
    echo -e "\n${CYAN}▶${NC} Test: Error message parsed correctly"

    local msg='{"v":1,"t":"error","a":"qwen","track":"fix-bug","err":"test_failed","detail":"3 tests failing"}'
    local output
    output=$(python3 -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/scripts')
from importlib.machinery import SourceFileLoader
handler = SourceFileLoader('handler', '$PROJECT_ROOT/scripts/protocol-handler.py').load_module()
msg = handler.parse_protocol_message('$msg')
print(f\"{msg.get('t')}|{msg.get('a')}|{msg.get('err')}\")
" 2>/dev/null)

    assert_equals "error|qwen|test_failed" "$output" "Error message parsed"
}

test_complete_message_parsed() {
    echo -e "\n${CYAN}▶${NC} Test: Complete message parsed correctly"

    local msg='{"v":1,"t":"complete","a":"claude","track":"write-docs","detail":"All sections complete"}'
    local output
    output=$(python3 -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/scripts')
from importlib.machinery import SourceFileLoader
handler = SourceFileLoader('handler', '$PROJECT_ROOT/scripts/protocol-handler.py').load_module()
msg = handler.parse_protocol_message('$msg')
print(f\"{msg.get('t')}|{msg.get('a')}|{msg.get('track')}\")
" 2>/dev/null)

    assert_equals "complete|claude|write-docs" "$output" "Complete message parsed"
}

test_heartbeat_message_parsed() {
    echo -e "\n${CYAN}▶${NC} Test: Heartbeat message parsed correctly"

    local msg='{"v":1,"t":"heartbeat","a":"deepseek","latency_ms":150,"load":0.3}'
    local output
    output=$(python3 -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/scripts')
from importlib.machinery import SourceFileLoader
handler = SourceFileLoader('handler', '$PROJECT_ROOT/scripts/protocol-handler.py').load_module()
msg = handler.parse_protocol_message('$msg')
print(f\"{msg.get('t')}|{msg.get('a')}|{msg.get('latency_ms')}\")
" 2>/dev/null)

    assert_equals "heartbeat|deepseek|150" "$output" "Heartbeat message parsed"
}

test_invalid_version_rejected() {
    echo -e "\n${CYAN}▶${NC} Test: Invalid version rejected"

    local msg='{"v":2,"t":"status","a":"gemini","pct":50}'
    local output
    output=$(python3 -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/scripts')
from importlib.machinery import SourceFileLoader
handler = SourceFileLoader('handler', '$PROJECT_ROOT/scripts/protocol-handler.py').load_module()
msg = handler.parse_protocol_message('$msg')
print('empty' if not msg else 'parsed')
" 2>/dev/null)

    assert_equals "empty" "$output" "Invalid version rejected"
}

test_invalid_type_rejected() {
    echo -e "\n${CYAN}▶${NC} Test: Invalid message type rejected"

    local msg='{"v":1,"t":"unknown_type","a":"gemini"}'
    local output
    output=$(python3 -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/scripts')
from importlib.machinery import SourceFileLoader
handler = SourceFileLoader('handler', '$PROJECT_ROOT/scripts/protocol-handler.py').load_module()
msg = handler.parse_protocol_message('$msg')
print('empty' if not msg else 'parsed')
" 2>/dev/null)

    assert_equals "empty" "$output" "Invalid type rejected"
}

test_non_json_rejected() {
    echo -e "\n${CYAN}▶${NC} Test: Non-JSON message rejected"

    local output
    output=$(python3 -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/scripts')
from importlib.machinery import SourceFileLoader
handler = SourceFileLoader('handler', '$PROJECT_ROOT/scripts/protocol-handler.py').load_module()
result = handler.is_protocol_message('This is plain English text')
print('true' if result else 'false')
" 2>/dev/null)

    assert_equals "false" "$output" "Non-JSON rejected"
}

test_json_with_commands_rejected() {
    echo -e "\n${CYAN}▶${NC} Test: JSON with commands rejected (not protocol)"

    local output
    output=$(python3 -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/scripts')
from importlib.machinery import SourceFileLoader
handler = SourceFileLoader('handler', '$PROJECT_ROOT/scripts/protocol-handler.py').load_module()
result = handler.is_protocol_message('{\"cmd\": \"test\"}')
print('true' if result else 'false')
" 2>/dev/null)

    # is_protocol_message checks if it starts with {, so this should be true
    # but parse_protocol_message will reject it because 't' is missing
    assert_equals "true" "$output" "JSON detected as potential protocol"
}

test_status_updates_blackboard() {
    echo -e "\n${CYAN}▶${NC} Test: Status message updates blackboard"

    local db_file="$PROJECT_ROOT/.ai-colab/test-protocol.db"
    mkdir -p "$PROJECT_ROOT/.ai-colab"

    # Create database first
    python3 -c "
import sqlite3
conn = sqlite3.connect('$db_file')
conn.execute('CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT, expires_at INTEGER DEFAULT 0)')
conn.commit()
conn.close()
"

    local output
    output=$(TEST_DB="$db_file" python3 -c "
import sys, os, json, sqlite3
db_file = os.environ.get('TEST_DB', '')
if not db_file:
    print('no_db')
    sys.exit(1)
os.environ['BLACKBOARD_DB_PATH'] = db_file
sys.path.insert(0, '$PROJECT_ROOT/scripts')
handler = __import__('protocol-handler')
msg = '{\"v\":1,\"t\":\"status\",\"a\":\"test_agent\",\"track\":\"test-track\",\"pct\":50,\"step\":\"testing\"}'
result = handler.process_protocol_message(msg)
if not result:
    print('not_processed')
    sys.exit(0)
conn = sqlite3.connect(db_file)
cursor = conn.execute('SELECT value FROM kv WHERE key = ?', ('agent_progress_test_agent',))
row = cursor.fetchone()
conn.close()
if row:
    data = json.loads(row[0])
    if data['pct'] == 50 and data['track'] == 'test-track':
        print('processed_and_verified')
    else:
        print('wrong_data')
else:
    print('no_data')
" 2>/dev/null)

    if [[ "$output" == "processed_and_verified" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Status message processed and verified"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Status message not verified (got: $output)"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    # Cleanup
    rm -f "$db_file"
}

test_error_updates_blackboard() {
    echo -e "\n${CYAN}▶${NC} Test: Error message updates blackboard"

    local db_file="$PROJECT_ROOT/.ai-colab/test-protocol.db"
    mkdir -p "$PROJECT_ROOT/.ai-colab"

    # Create test database
    python3 -c "
import sqlite3
conn = sqlite3.connect('$db_file')
conn.execute('CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT, expires_at INTEGER DEFAULT 0)')
conn.commit()
conn.close()
"

    local output
    output=$(BLACKBOARD_DB_PATH="$db_file" python3 -c "
import sys, os
os.environ['BLACKBOARD_DB_PATH'] = '$db_file'
sys.path.insert(0, '$PROJECT_ROOT/scripts')
from importlib.machinery import SourceFileLoader
handler = SourceFileLoader('handler', '$PROJECT_ROOT/scripts/protocol-handler.py').load_module()
msg = '{\"v\":1,\"t\":\"error\",\"a\":\"test_agent\",\"track\":\"test-track\",\"err\":\"test_failed\",\"detail\":\"3 tests failing\"}'
result = handler.process_protocol_message(msg)
print('processed' if result else 'not_processed')
" 2>/dev/null)

    assert_equals "processed" "$output" "Error message processed"

    # Verify error queue was updated
    local errors
    errors=$(python3 -c "
import sqlite3
conn = sqlite3.connect('$db_file')
cursor = conn.execute('SELECT value FROM kv WHERE key = ?', ('protocol_errors',))
row = cursor.fetchone()
conn.close()
print(row[0] if row else 'none')
" 2>/dev/null)

    if echo "$errors" | grep -q "test_failed"; then
        echo -e "${GREEN}✓ PASS:${NC} Error queue updated"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Error queue not updated"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    # Cleanup
    rm -f "$db_file"
}

test_handler_in_conductor() {
    echo -e "\n${CYAN}▶${NC} Test: Conductor references protocol handler"

    if grep -q "process_protocol_message" "$PROJECT_ROOT/scripts/conductor-workflow.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Conductor calls protocol handler"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Conductor should call protocol handler"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_handler_handles_malformed_json() {
    echo -e "\n${CYAN}▶${NC} Test: Handler handles malformed JSON gracefully"

    local output
    output=$(python3 -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT/scripts')
from importlib.machinery import SourceFileLoader
handler = SourceFileLoader('handler', '$PROJECT_ROOT/scripts/protocol-handler.py').load_module()
try:
    msg = handler.parse_protocol_message('{invalid json}')
    print('handled_gracefully' if not msg else 'unexpected')
except Exception:
    print('exception')
" 2>/dev/null)

    assert_equals "handled_gracefully" "$output" "Malformed JSON handled gracefully"
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Conductor Protocol Handler Test Suite (P6.3)      ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_handler_file_exists
    test_handler_syntax
    test_status_message_parsed
    test_error_message_parsed
    test_complete_message_parsed
    test_heartbeat_message_parsed
    test_invalid_version_rejected
    test_invalid_type_rejected
    test_non_json_rejected
    test_json_with_commands_rejected
    test_status_updates_blackboard
    test_error_updates_blackboard
    test_handler_in_conductor
    test_handler_handles_malformed_json

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
