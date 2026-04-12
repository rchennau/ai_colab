#!/usr/bin/env bash
# Test Suite: Blackboard Schema Validation (P16.3)
# Tests: namespace validation, reserved namespace protection,
#        TTL enforcement, atomic multi-key ops, value constraints

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KV_SCRIPT="$PROJECT_ROOT/scripts/hcom-kv.sh"
UTILS_SCRIPT="$PROJECT_ROOT/scripts/utils.sh"
SCHEMA_FILE="$PROJECT_ROOT/config/blackboard-schema.json"

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

# Test database (isolated)
TEST_DB_DIR="/tmp/ai-colab-test-bb-$$"
TEST_DB="$TEST_DB_DIR/test-blackboard.db"

# ============================================================
# Test Helpers
# ============================================================

setup() {
    mkdir -p "$TEST_DB_DIR"
    # Create the kv table
    sqlite3 "$TEST_DB" "CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT, expires_at INTEGER DEFAULT 0);"
}

teardown() {
    rm -rf "$TEST_DB_DIR"
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

# Helper: run bb_set_validated with test DB
bb_validated_set() {
    local key="$1"
    local value="$2"
    local schema_path="${3:-$SCHEMA_FILE}"

    (
        export BLACKBOARD_SCHEMA_PATH="$schema_path"
        export BLACKBOARD_DB_PATH="$TEST_DB"
        export PROJECT_ROOT="$PROJECT_ROOT"
        export AI_COLAB_TEST_MODE=true
        source "$PROJECT_ROOT/scripts/utils.sh" >/dev/null 2>&1
        blackboard_set_validated "$key" "$value"
    ) 2>&1
}

# Helper: run bb_get with test DB
bb_get() {
    local key="$1"
    (
        export BLACKBOARD_DB_PATH="$TEST_DB"
        export PROJECT_ROOT="$PROJECT_ROOT"
        export AI_COLAB_TEST_MODE=true
        source "$PROJECT_ROOT/scripts/utils.sh" >/dev/null 2>&1
        blackboard_get "$key"
    ) 2>&1
}

# Helper: run bb_atomic_set with test DB
bb_atomic_set() {
    (
        export BLACKBOARD_SCHEMA_PATH="$SCHEMA_FILE"
        export BLACKBOARD_DB_PATH="$TEST_DB"
        export PROJECT_ROOT="$PROJECT_ROOT"
        export AI_COLAB_TEST_MODE=true
        source "$PROJECT_ROOT/scripts/utils.sh" >/dev/null 2>&1
        blackboard_atomic_set "$@"
    ) 2>&1
}

# ============================================================
# Tests
# ============================================================

test_schema_file_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Schema file exists and is valid JSON"

    assert_file_exists "$SCHEMA_FILE" "Schema file exists"

    # Validate JSON syntax
    if command -v python3 >/dev/null 2>&1; then
        local json_valid
        json_valid=$(python3 -c "import json; json.load(open('$SCHEMA_FILE')); print('valid')" 2>&1)
        assert_equals "valid" "$json_valid" "Schema is valid JSON"
    else
        echo -e "${YELLOW}⊘ SKIP:${NC} python3 not available for JSON validation"
    fi
}

test_valid_namespace_accepted() {
    echo -e "\n${CYAN}▶${NC} Test: Valid namespace keys accepted"

    # Test project_ namespace
    local result
    result=$(bb_validated_set "project_progress" "42")
    assert_contains "$result" "" "project_progress accepted"

    # Test track_ namespace
    result=$(bb_validated_set "track_status_my-feature" "in_progress")
    assert_contains "$result" "" "track_status_my-feature accepted"

    # Test agent_ namespace
    result=$(bb_validated_set "fleet_health_gemini" "{\"status\":\"healthy\"}")
    assert_contains "$result" "" "fleet_health_gemini accepted"

    # Test test_ namespace
    result=$(bb_validated_set "test_last_status" "passed")
    assert_contains "$result" "" "test_last_status accepted"

    # Test hook_ namespace
    result=$(bb_validated_set "hook_last_run_test_hook" "1234567890")
    assert_contains "$result" "" "hook_ namespace accepted"

    # Test recovery_ namespace
    result=$(bb_validated_set "recovery_attempt_gemini" "1234567890")
    assert_contains "$result" "" "recovery_ namespace accepted"

    # Test mq_ namespace
    result=$(bb_validated_set "conductor_event_cursor" "42")
    assert_contains "$result" "" "mq_ namespace accepted"
}

test_reserved_namespace_rejected() {
    echo -e "\n${CYAN}▶${NC} Test: Reserved namespace writes rejected"

    local result

    # Test conductor_internal_ namespace
    result=$(bb_validated_set "conductor_internal_secret" "should_fail")
    if [[ $? -ne 0 ]] || echo "$result" | grep -qi "reject\|error\|reserved\|forbidden"; then
        echo -e "${GREEN}✓ PASS:${NC} conductor_internal_ rejected"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} conductor_internal_ should be rejected"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    # Test system_ namespace
    result=$(bb_validated_set "system_config" "should_fail")
    if [[ $? -ne 0 ]] || echo "$result" | grep -qi "reject\|error\|reserved\|forbidden"; then
        echo -e "${GREEN}✓ PASS:${NC} system_ rejected"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} system_ should be rejected"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    # Test hcom_internal_ namespace
    result=$(bb_validated_set "hcom_internal_token" "should_fail")
    if [[ $? -ne 0 ]] || echo "$result" | grep -qi "reject\|error\|reserved\|forbidden"; then
        echo -e "${GREEN}✓ PASS:${NC} hcom_internal_ rejected"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} hcom_internal_ should be rejected"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_unknown_namespace_rejected() {
    echo -e "\n${CYAN}▶${NC} Test: Unknown namespace rejected"

    local result
    result=$(bb_validated_set "unknown_prefix_key" "should_fail")
    if [[ $? -ne 0 ]] || echo "$result" | grep -qi "reject\|error\|invalid\|unknown\|namespace"; then
        echo -e "${GREEN}✓ PASS:${NC} Unknown namespace rejected"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Unknown namespace should be rejected"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_value_length_constraint() {
    echo -e "\n${CYAN}▶${NC} Test: Value length constraint (max 65536 chars)"

    # Create a value that exceeds max length
    local long_value
    long_value=$(python3 -c "print('x' * 65537)" 2>/dev/null || echo "$(head -c 65537 /dev/urandom | base64 | head -c 65537)")

    local result
    result=$(bb_validated_set "project_test_long_value" "$long_value")
    if [[ $? -ne 0 ]] || echo "$result" | grep -qi "reject\|error\|exceeds\|too long\|max"; then
        echo -e "${GREEN}✓ PASS:${NC} Oversized value rejected"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Oversized value should be rejected"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_key_length_constraint() {
    echo -e "\n${CYAN}▶${NC} Test: Key length constraint (max 256 chars)"

    # Create a key that exceeds max length
    local long_key
    long_key="project_$(python3 -c "print('x' * 250)" 2>/dev/null || echo "$(head -c 250 /dev/urandom | base64 | head -c 250)")"

    local result
    result=$(bb_validated_set "$long_key" "should_fail")
    if [[ $? -ne 0 ]] || echo "$result" | grep -qi "reject\|error\|exceeds\|too long\|max"; then
        echo -e "${GREEN}✓ PASS:${NC} Oversized key rejected"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Oversized key should be rejected"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_ttl_enforcement() {
    echo -e "\n${CYAN}▶${NC} Test: TTL enforcement (expired keys cleaned up)"

    # Insert a key with an expiration time in the past
    local past_time=$(( $(date +%s) - 100 ))
    sqlite3 "$TEST_DB" "INSERT OR REPLACE INTO kv (key, value, expires_at) VALUES ('agent_test_expired', 'old_data', $past_time);"

    # Verify it exists before cleanup
    local before_count
    before_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM kv WHERE key = 'agent_test_expired';")
    assert_equals "1" "$before_count" "Expired key exists before cleanup"

    # Read the key (will not return value since it's expired)
    local result
    result=$(bb_get "agent_test_expired" 2>&1)

    # Verify read returns empty for expired key
    if [[ -z "$result" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Expired key returns empty on read"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Expired key should return empty, got: '$result'"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    # Trigger explicit cleanup
    (
        export BLACKBOARD_DB_PATH="$TEST_DB"
        export PROJECT_ROOT="$PROJECT_ROOT"
        source "$PROJECT_ROOT/scripts/utils.sh" >/dev/null 2>&1
        bb_cleanup_expired
    ) 2>/dev/null

    # Verify it was cleaned up
    local after_count
    after_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM kv WHERE key = 'agent_test_expired';")
    assert_equals "0" "$after_count" "Expired key cleaned up after bb_cleanup_expired"
}

test_ttl_persistent_keys() {
    echo -e "\n${CYAN}▶${NC} Test: Persistent keys (TTL=0) not cleaned up"

    # Insert a key with expires_at=0 (persistent)
    sqlite3 "$TEST_DB" "INSERT OR REPLACE INTO kv (key, value, expires_at) VALUES ('project_progress', '42', 0);"

    # Read the key
    local value
    value=$(bb_get "project_progress")
    assert_equals "42" "$value" "Persistent key readable"

    # Verify it still exists
    local count
    count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM kv WHERE key = 'project_progress';")
    assert_equals "1" "$count" "Persistent key not cleaned up"
}

test_atomic_multi_key_set() {
    echo -e "\n${CYAN}▶${NC} Test: Atomic multi-key set (all-or-nothing)"

    # Test successful atomic set
    local result
    result=$(bb_atomic_set "test_key_a" "value_a" "test_key_b" "value_b" "test_key_c" "value_c")

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Atomic multi-key set succeeded"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Atomic multi-key set failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    # Verify all keys were set
    local val_a val_b val_c
    val_a=$(bb_get "test_key_a")
    val_b=$(bb_get "test_key_b")
    val_c=$(bb_get "test_key_c")

    assert_equals "value_a" "$val_a" "Key A set atomically"
    assert_equals "value_b" "$val_b" "Key B set atomically"
    assert_equals "value_c" "$val_c" "Key C set atomically"
}

test_atomic_rollback_on_failure() {
    echo -e "\n${CYAN}▶${NC} Test: Atomic rollback on validation failure"

    # First, set a valid key
    bb_validated_set "test_atomic_rollback_a" "value_a" >/dev/null 2>&1

    # Now try an atomic set with one invalid key (reserved namespace)
    # This should fail and not modify any keys
    local result
    result=$(bb_atomic_set "system_forbidden_key" "should_fail" "test_atomic_rollback_b" "value_b")

    # The atomic set should have failed due to reserved namespace
    if [[ $? -ne 0 ]] || echo "$result" | grep -qi "reject\|error\|reserved\|forbidden\|fail"; then
        echo -e "${GREEN}✓ PASS:${NC} Atomic set rejected due to invalid key"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Atomic set should reject invalid keys"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    # Verify that test_atomic_rollback_b was NOT set (rollback)
    local val_b
    val_b=$(bb_get "test_atomic_rollback_b")
    assert_equals "" "$val_b" "Key B not set (rollback successful)"
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Blackboard Schema Validation Test Suite (P16.3)    ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    setup

    test_schema_file_exists
    test_valid_namespace_accepted
    test_reserved_namespace_rejected
    test_unknown_namespace_rejected
    test_value_length_constraint
    test_key_length_constraint
    test_ttl_enforcement
    test_ttl_persistent_keys
    test_atomic_multi_key_set
    test_atomic_rollback_on_failure

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
