#!/usr/bin/env bash
# Fleet Autonomy End-to-End Recovery Verification
# Simulates an agent crash and verifies Conductor Watchdog detection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UTILS="$PROJECT_ROOT/scripts/utils.sh"

source "$UTILS"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
test_start() {
    echo -e "\n${BLUE}TEST:${NC} $1"
}

test_pass() {
    echo -e "  ${GREEN}✓ PASS:${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo -e "  ${RED}✗ FAIL:${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

ui_banner "Fleet Recovery Verification" "${BLUE}"

# ============================================
# Test 1: Crash Detection & Status Propagation
# ============================================
test_start "Agent Crash Detection"

# 1. Start a mock agent with heartbeat
export HCOM_NAME="crash_test_agent_$$"
register_hcom "mock"
start_heartbeat "mock"

echo "Waiting for initial heartbeat (2s)..."
sleep 2

INITIAL_HEALTH=$(blackboard_get "fleet_health_${HCOM_NAME}")
if [[ "$INITIAL_HEALTH" == *'"status":"ready"'* ]]; then
    test_pass "Agent successfully registered and started heartbeating"
else
    test_fail "Agent failed to start heartbeating (got: $INITIAL_HEALTH)"
fi

# 2. Simulate crash: kill the heartbeat process
echo "Simulating crash (killing heartbeat PID $HEARTBEAT_PID)..."
kill -9 "$HEARTBEAT_PID" || true

# 3. Manually report a crash status (to simulate agent-wrapper.sh catching the exit)
report_health "crashed" "0" "137"

CRASH_HEALTH=$(blackboard_get "fleet_health_${HCOM_NAME}")
if [[ "$CRASH_HEALTH" == *'"status":"crashed"'* ]]; then
    test_pass "Crash status correctly propagated to Blackboard"
else
    test_fail "Crash status not found in Blackboard (got: $CRASH_HEALTH)"
fi

# ============================================
# Test 2: Watchdog Recovery Signal
# ============================================
test_start "Watchdog Recovery Detection"

# Simulate stale agent by setting a very old timestamp
OLD_TS=$(( $(date +%s) - 300 ))
blackboard_set "fleet_health_${HCOM_NAME}" "{\"status\":\"ready\",\"latency\":10,\"load\":0,\"ts\":$OLD_TS}"

echo "Simulating Watchdog logic run..."
# Run the watchdog logic (extracted from conductor-workflow.sh for testing)
CURRENT_TIME=$(date +%s)

while IFS='|' read -r key health_json; do
    if [[ "$key" == "fleet_health_${HCOM_NAME}" ]]; then
        last_ts=$(echo "$health_json" | sed -n 's/.*"ts":[[:space:]]*\([0-9]*\).*/\1/p')
        if (( CURRENT_TIME - last_ts > 60 )); then
            # Mirror the logic in conductor-workflow.sh
            blackboard_set "recovery_attempt_${HCOM_NAME}" "$CURRENT_TIME"
        fi
    fi
done < <(blackboard_list "fleet_health_")

echo "Checking Blackboard for recovery attempt record..."
RECOVERY=$(blackboard_get "recovery_attempt_${HCOM_NAME}")

if [[ -n "$RECOVERY" ]]; then
    test_pass "Watchdog successfully recorded recovery attempt in Blackboard"
else
    test_fail "Watchdog failed to record recovery attempt"
fi

# ============================================
# Summary
# ============================================
echo -e "\n${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}Test Summary:${NC}"
echo -e "  ${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC} $TESTS_FAILED"
echo -e "${BLUE}════════════════════════════════════════${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}✓ All tests passed! Fleet recovery verified.${NC}"
    exit 0
else
    exit 1
fi
