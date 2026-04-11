#!/usr/bin/env bash
# Test Suite: Message Queue Layer (P16.1)
# Tests: send, deliver, queue, retry, dead-letter, cleanup

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MQ_SCRIPT="$PROJECT_ROOT/scripts/message-queue.sh"

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

# Test database location (isolated for testing)
TEST_MQ_DB_DIR="/tmp/ai-colab-test-mq-$$"
TEST_MQ_DB="$TEST_MQ_DB_DIR/messages.db"

# ============================================================
# Test Helpers
# ============================================================

setup() {
    mkdir -p "$TEST_MQ_DB_DIR"
    # Unset any existing MQ vars to ensure clean state
    unset MQ_DB_DIR MQ_DB 2>/dev/null || true
}

teardown() {
    rm -rf "$TEST_MQ_DB_DIR"
    unset MQ_DB_DIR MQ_DB
}

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

    if [[ $a -gt $b ]]; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        echo -e "  Expected $a > $b"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Tests
# ============================================================

test_mq_init() {
    echo -e "\n${CYAN}▶${NC} Test: Message queue initialization"

    MQ_DB_DIR="$TEST_MQ_DB_DIR" MQ_DB="$TEST_MQ_DB" bash "$MQ_SCRIPT" init

    assert_contains "$(ls "$TEST_MQ_DB_DIR")" "messages.db" "Database file created"

    # Verify tables exist
    local tables
    tables=$(sqlite3 "$TEST_MQ_DB" ".tables")
    assert_contains "$tables" "messages" "Messages table created"
    assert_contains "$tables" "dead_letter_queue" "Dead letter view created"
    assert_contains "$tables" "pending_messages" "Pending view created"
}

test_mq_send() {
    echo -e "\n${CYAN}▶${NC} Test: Message send (offline agent)"

    # Send to an agent that doesn't exist (offline)
    local msg_id
    msg_id=$(MQ_DB_DIR="$TEST_MQ_DB_DIR" MQ_DB="$TEST_MQ_DB" bash "$MQ_SCRIPT" send "offline_agent" "Test message content" "conductor" "inform" "test" 3 86400)

    assert_contains "$msg_id" "msg_" "Message ID generated"

    # Verify message is in database
    local status
    status=$(sqlite3 "$TEST_MQ_DB" "SELECT status FROM messages WHERE id = '$msg_id';")
    assert_equals "pending" "$status" "Message is pending (agent offline)"

    # Verify message content
    local content
    content=$(sqlite3 "$TEST_MQ_DB" "SELECT content FROM messages WHERE id = '$msg_id';")
    assert_equals "Test message content" "$content" "Message content stored correctly"
}

test_mq_pending_count() {
    echo -e "\n${CYAN}▶${NC} Test: Pending message count"

    # Send multiple messages
    MQ_DB_DIR="$TEST_MQ_DB_DIR" MQ_DB="$TEST_MQ_DB" bash "$MQ_SCRIPT" send "test_agent" "Message 1" "sender1" "inform" "test" >/dev/null
    MQ_DB_DIR="$TEST_MQ_DB_DIR" MQ_DB="$TEST_MQ_DB" bash "$MQ_SCRIPT" send "test_agent" "Message 2" "sender2" "inform" "test" >/dev/null
    MQ_DB_DIR="$TEST_MQ_DB_DIR" MQ_DB="$TEST_MQ_DB" bash "$MQ_SCRIPT" send "test_agent" "Message 3" "sender3" "inform" "test" >/dev/null

    local pending
    pending=$(MQ_DB_DIR="$TEST_MQ_DB_DIR" MQ_DB="$TEST_MQ_DB" bash "$MQ_SCRIPT" pending "test_agent")
    assert_gt "$pending" "2" "At least 3 pending messages for test_agent"
}

test_mq_ack() {
    echo -e "\n${CYAN}▶${NC} Test: Message acknowledgment"

    # Get a pending message
    local msg_id
    msg_id=$(sqlite3 "$TEST_MQ_DB" "SELECT id FROM messages WHERE status = 'pending' LIMIT 1;")

    if [[ -n "$msg_id" ]]; then
        MQ_DB_DIR="$TEST_MQ_DB_DIR" MQ_DB="$TEST_MQ_DB" bash "$MQ_SCRIPT" ack "$msg_id"

        local status
        status=$(sqlite3 "$TEST_MQ_DB" "SELECT status FROM messages WHERE id = '$msg_id';")
        assert_equals "acked" "$status" "Message acknowledged"

        local acked_at
        acked_at=$(sqlite3 "$TEST_MQ_DB" "SELECT acked_at FROM messages WHERE id = '$msg_id';")
        assert_contains "$acked_at" "-" "Acknowledgment timestamp set"
    else
        echo -e "${YELLOW}⊘ SKIP:${NC} No pending message to ack"
    fi
}

test_mq_status() {
    echo -e "\n${CYAN}▶${NC} Test: Message queue status"

    local status_output
    status_output=$(MQ_DB_DIR="$TEST_MQ_DB_DIR" MQ_DB="$TEST_MQ_DB" bash "$MQ_SCRIPT" status)

    assert_contains "$status_output" "Total:" "Status shows total count"
    assert_contains "$status_output" "Pending:" "Status shows pending count"
    assert_contains "$status_output" "Delivered:" "Status shows delivered count"
    assert_contains "$status_output" "Acknowledged:" "Status shows acknowledged count"
    assert_contains "$status_output" "Failed:" "Status shows failed count"
}

test_mq_ttl_expiration() {
    echo -e "\n${CYAN}▶${NC} Test: Message TTL expiration"

    # Insert a message with 0-second TTL (already expired)
    local msg_id
    msg_id="msg_expired_test_$$"
    sqlite3 "$TEST_MQ_DB" << SQL
INSERT INTO messages (id, target, sender, content, intent, thread, max_retries, ttl_seconds, created_at)
VALUES ('$msg_id', 'test_agent', 'test', 'Expired message', 'inform', 'test', 3, 0, datetime('now', '-1 hour'));
SQL

    # Run cleanup
    MQ_DB_DIR="$TEST_MQ_DB_DIR" MQ_DB="$TEST_MQ_DB" bash "$MQ_SCRIPT" cleanup

    # Verify expired message was removed
    local count
    count=$(sqlite3 "$TEST_MQ_DB" "SELECT COUNT(*) FROM messages WHERE id = '$msg_id';")
    assert_equals "0" "$count" "Expired message cleaned up"
}

test_mq_queue_depth() {
    echo -e "\n${CYAN}▶${NC} Test: Queue depth per agent"

    local depth
    depth=$(MQ_DB_DIR="$TEST_MQ_DB_DIR" MQ_DB="$TEST_MQ_DB" bash "$MQ_SCRIPT" queue-depth "test_agent")

    assert_gt "$depth" "-1" "Queue depth is non-negative"
}

test_mq_get_pending() {
    echo -e "\n${CYAN}▶${NC} Test: Get pending messages for agent"

    local pending_msgs
    pending_msgs=$(MQ_DB_DIR="$TEST_MQ_DB_DIR" MQ_DB="$TEST_MQ_DB" bash "$MQ_SCRIPT" get-pending "test_agent")

    assert_contains "$pending_msgs" "|" "Pending messages returned with data"
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Message Queue Test Suite (P16.1)                   ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    setup

    test_mq_init
    test_mq_send
    test_mq_pending_count
    test_mq_ack
    test_mq_status
    test_mq_ttl_expiration
    test_mq_queue_depth
    test_mq_get_pending

    teardown

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
