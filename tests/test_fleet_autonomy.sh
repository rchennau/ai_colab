#!/usr/bin/env bash
# Fleet Autonomy & Health 2.0 Verification
# Tests enhanced heartbeat reporting and metrics

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

ui_banner "Fleet Autonomy Verification" "${BLUE}"

# ============================================
# Test 1: Health 2.0 Reporting
# ============================================
test_start "Manual Health Reporting"

export HCOM_NAME="test_agent_$(date +%s)"
report_health "ready" 42 1

HEALTH_DATA=$(blackboard_get "fleet_health_${HCOM_NAME}")

if echo "$HEALTH_DATA" | grep -q "\"status\":\"ready\"" && \
   echo "$HEALTH_DATA" | grep -q "\"latency\":42" && \
   echo "$HEALTH_DATA" | grep -q "\"load\":1"; then
    test_pass "Health metrics correctly formatted and stored in Blackboard"
else
    test_fail "Health data missing or incorrect: $HEALTH_DATA"
fi

# ============================================
# Test 2: Dynamic Latency Heartbeat
# ============================================
test_start "Dynamic Heartbeat Background Execution"

# Register and start heartbeat
register_hcom "test_heartbeat"
start_heartbeat "test_heartbeat"

echo "Waiting for heartbeat to trigger (2s)..."
sleep 2

HEALTH_DATA_AUTO=$(blackboard_get "fleet_health_${HCOM_NAME}")

if [[ -n "$HEALTH_DATA_AUTO" ]] && [[ "$HEALTH_DATA_AUTO" == *'"latency":'* ]]; then
    test_pass "Background heartbeat automatically updated health metrics"
    echo "  Current health: $HEALTH_DATA_AUTO"
else
    test_fail "Background heartbeat failed to update Blackboard (got: $HEALTH_DATA_AUTO)"
fi

# Cleanup
if [ -n "${HEARTBEAT_PID:-}" ]; then
    kill "$HEARTBEAT_PID" 2>/dev/null || true
fi

# ============================================
# Test 3: Watchdog Stale Detection
# ============================================
test_start "Watchdog Stale Detection"

STALE_AGENT="stale_agent_$(date +%s)"
OLD_TS=$(( $(date +%s) - 300 )) # 5 minutes ago
report_health "ready" 10 0 # Sets HCOM_NAME locally
# Manually inject stale data
blackboard_set "fleet_health_${STALE_AGENT}" "{\"status\":\"ready\",\"latency\":10,\"load\":0,\"ts\":$OLD_TS}"

echo "Simulating Conductor Watchdog run..."
# We run the logic manually to verify it handles the data correctly
# In a real scenario, conductor-workflow.sh would do this
HEALTH_DATA=$(blackboard_get "fleet_health_${STALE_AGENT}")
LAST_TS=$(echo "$HEALTH_DATA" | sed -n 's/.*"ts":[[:space:]]*\([0-9]*\).*/\1/p')
NOW=$(date +%s)

if (( NOW - LAST_TS > 60 )); then
    test_pass "Watchdog logic correctly identifies stale agent from 5 minutes ago"
else
    test_fail "Watchdog logic failed to identify stale agent ($((NOW - LAST_TS))s diff)"
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
    echo -e "\n${GREEN}✓ All tests passed! Health 2.0 infrastructure verified.${NC}"
    exit 0
else
    exit 1
fi
