#!/usr/bin/env bash
# hcom Automated Test Runner
# Executes all project tests and reports status to the Blackboard

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

PROJECT_ROOT=$(detect_project_root)
TEST_DIR="$PROJECT_ROOT/tests"
KV_TOOL="$SCRIPT_DIR/hcom-kv"

echo "========================================="
echo "  ai-colab Automated Test Runner"
echo "========================================="

TOTAL=0
PASSED=0
FAILED=0
FAILED_LIST=""

# Find all shell scripts in tests directory
for test_file in "$TEST_DIR"/test_*.sh; do
    [[ -e "$test_file" ]] || continue
    
    TOTAL=$((TOTAL + 1))
    echo -n "Running $(basename "$test_file")... "
    
    # Run test and capture output
    if bash "$test_file" > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}"
        FAILED=$((FAILED + 1))
        FAILED_LIST="$FAILED_LIST $(basename "$test_file")"
    fi
done

# Calculate status
STATUS="PASS"
[[ $FAILED -gt 0 ]] && STATUS="FAIL"

# Update Blackboard
"$KV_TOOL" set "test_last_run_at" "$(date '+%Y-%m-%dT%H:%M:%S%z')"
"$KV_TOOL" set "test_last_status" "$STATUS"
"$KV_TOOL" set "test_fail_count" "$FAILED"
"$KV_TOOL" set "test_total_count" "$TOTAL"

# Broadcast to team
SUMMARY="Test Run: $STATUS ($PASSED/$TOTAL passed). Failures: ${FAILED_LIST:-None}"
if has_command hcom; then
    hcom send @all --intent inform --thread "plan-sync" -- "$SUMMARY"
fi

echo ""
echo "$SUMMARY"
echo "========================================="

# Return non-zero if any tests failed
[[ $FAILED -eq 0 ]] || exit 1
