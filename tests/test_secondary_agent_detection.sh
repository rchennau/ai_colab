#!/usr/bin/env bash
# Test Suite: Secondary Agent Detection (P25.4)
# Tests: conductor monitoring, stale detection, alerting, blackboard updates

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

test_conductor_monitor_function_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Conductor monitor function exists"

    if grep -q "start_conductor_monitor" "$PROJECT_ROOT/scripts/utils.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} start_conductor_monitor function exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} start_conductor_monitor function missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_check_conductor_status_function_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Check conductor status function exists"

    if grep -q "check_conductor_status" "$PROJECT_ROOT/scripts/utils.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} check_conductor_status function exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} check_conductor_status function missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_agent_wrapper_starts_conductor_monitor() {
    echo -e "\n${CYAN}▶${NC} Test: Agent wrapper starts conductor monitor"

    if grep -q "start_conductor_monitor" "$PROJECT_ROOT/scripts/agent-wrapper.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Agent wrapper starts conductor monitor"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Agent wrapper should start conductor monitor"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_agent_wrapper_cleans_up_conductor_monitor() {
    echo -e "\n${CYAN}▶${NC} Test: Agent wrapper cleans up conductor monitor"

    if grep -q "CONDUCTOR_MONITOR_PID" "$PROJECT_ROOT/scripts/agent-wrapper.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Agent wrapper cleans up conductor monitor"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Agent wrapper should clean up conductor monitor"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_conductor_monitor_has_stale_detection() {
    echo -e "\n${CYAN}▶${NC} Test: Conductor monitor has stale detection"

    if grep -q "conductor_age.*90\|90.*conductor_age\|stale" "$PROJECT_ROOT/scripts/utils.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Conductor monitor has stale detection"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Conductor monitor should have stale detection"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_conductor_monitor_reports_to_blackboard() {
    echo -e "\n${CYAN}▶${NC} Test: Conductor monitor reports to blackboard"

    if grep -q "agent_conductor_status" "$PROJECT_ROOT/scripts/utils.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Conductor monitor reports to blackboard"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Conductor monitor should report to blackboard"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_conductor_monitor_updates_agent_health() {
    echo -e "\n${CYAN}▶${NC} Test: Conductor monitor updates agent health"

    if grep -q "agent_health.*conductor\|fleet_health.*agent_health" "$PROJECT_ROOT/scripts/utils.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Conductor monitor updates agent health"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Conductor monitor should update agent health"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_check_conductor_status_returns_healthy() {
    echo -e "\n${CYAN}▶${NC} Test: check_conductor_status returns healthy"

    # Create test database with recent heartbeat
    local db_file="$PROJECT_ROOT/.ai-colab/test-conductor-monitor.db"
    mkdir -p "$PROJECT_ROOT/.ai-colab"

    python3 -c "
import sqlite3, time
conn = sqlite3.connect('$db_file')
conn.execute('CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT, expires_at INTEGER DEFAULT 0)')
now = int(time.time())
hb = '{\"ts\":' + str(now - 10) + ',\"status\":\"running\"}'
conn.execute('INSERT OR REPLACE INTO kv (key, value, expires_at) VALUES (?, ?, 0)', ('conductor_heartbeat', hb))
conn.commit()
conn.close()
"

    local output
    output=$(BLACKBOARD_DB_PATH="$db_file" bash -c "
        source '$PROJECT_ROOT/scripts/utils.sh' 2>/dev/null
        check_conductor_status
    " 2>/dev/null)

    if [[ "$output" == healthy:* ]]; then
        echo -e "${GREEN}✓ PASS:${NC} check_conductor_status returns healthy"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} check_conductor_status should return healthy (got: $output)"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    rm -f "$db_file"
}

test_check_conductor_status_returns_stale() {
    echo -e "\n${CYAN}▶${NC} Test: check_conductor_status returns stale"

    # Create test database with old heartbeat
    local db_file="$PROJECT_ROOT/.ai-colab/test-conductor-monitor.db"
    mkdir -p "$PROJECT_ROOT/.ai-colab"

    python3 -c "
import sqlite3, time
conn = sqlite3.connect('$db_file')
conn.execute('CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT, expires_at INTEGER DEFAULT 0)')
now = int(time.time())
hb = '{\"ts\":' + str(now - 200) + ',\"status\":\"running\"}'  # 200s ago (>90s stale)
conn.execute('INSERT OR REPLACE INTO kv (key, value, expires_at) VALUES (?, ?, 0)', ('conductor_heartbeat', hb))
conn.commit()
conn.close()
"

    local output
    output=$(BLACKBOARD_DB_PATH="$db_file" bash -c "
        source '$PROJECT_ROOT/scripts/utils.sh' 2>/dev/null
        check_conductor_status
    " 2>/dev/null)

    if [[ "$output" == stale:* ]]; then
        echo -e "${GREEN}✓ PASS:${NC} check_conductor_status returns stale"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} check_conductor_status should return stale (got: $output)"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    rm -f "$db_file"
}

test_check_conductor_status_returns_no_heartbeat() {
    echo -e "\n${CYAN}▶${NC} Test: check_conductor_status returns no_heartbeat"

    # Create test database without heartbeat
    local db_file="$PROJECT_ROOT/.ai-colab/test-conductor-monitor.db"
    mkdir -p "$PROJECT_ROOT/.ai-colab"

    python3 -c "
import sqlite3
conn = sqlite3.connect('$db_file')
conn.execute('CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT, expires_at INTEGER DEFAULT 0)')
conn.commit()
conn.close()
"

    local output
    output=$(BLACKBOARD_DB_PATH="$db_file" bash -c "
        source '$PROJECT_ROOT/scripts/utils.sh' 2>/dev/null
        check_conductor_status
    " 2>/dev/null)

    if [[ "$output" == "no_heartbeat" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} check_conductor_status returns no_heartbeat"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} check_conductor_status should return no_heartbeat (got: $output)"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    rm -f "$db_file"
}

test_conductor_monitor_has_alert_logging() {
    echo -e "\n${CYAN}▶${NC} Test: Conductor monitor has alert logging"

    if grep -q "WARNING.*Conductor heartbeat\|Conductor heartbeat.*WARNING" "$PROJECT_ROOT/scripts/utils.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Conductor monitor has alert logging"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Conductor monitor should have alert logging"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_conductor_monitor_has_status_change_detection() {
    echo -e "\n${CYAN}▶${NC} Test: Conductor monitor has status change detection"

    if grep -q "last_conductor_status\|conductor_status.*!=\|!=.*conductor_status" "$PROJECT_ROOT/scripts/utils.sh"; then
        echo -e "${GREEN}✓ PASS:${NC} Conductor monitor has status change detection"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Conductor monitor should have status change detection"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Secondary Agent Detection Test Suite (P25.4)       ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_conductor_monitor_function_exists
    test_check_conductor_status_function_exists
    test_agent_wrapper_starts_conductor_monitor
    test_agent_wrapper_cleans_up_conductor_monitor
    test_conductor_monitor_has_stale_detection
    test_conductor_monitor_reports_to_blackboard
    test_conductor_monitor_updates_agent_health
    test_check_conductor_status_returns_healthy
    test_check_conductor_status_returns_stale
    test_check_conductor_status_returns_no_heartbeat
    test_conductor_monitor_has_alert_logging
    test_conductor_monitor_has_status_change_detection

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
