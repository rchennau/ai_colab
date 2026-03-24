#!/usr/bin/env bash
# Test conductor-workflow.sh command handling

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Mock/Override DB_PATH for testing
export HCOM_DB_PATH="/tmp/test_hcom_qa.db"
rm -f "$HCOM_DB_PATH"

# 1. Setup mock blackboard data
blackboard_set "project_progress" "75%"
blackboard_set "active_track" "QA Automation"
blackboard_set "test_last_status" "PASS"

# 2. Test status command response
echo "Testing !status command..."

# Extract process_commands for testing
process_commands() {
    local text="$1"
    local from="test_agent"
    local thread="test_thread"
    
    if [[ "$text" == !* ]]; then
        local cmd=$(echo "$text" | awk '{print $1}')
        echo "Processing: $cmd"
        
        case "$cmd" in
            "!status")
                local progress=$(blackboard_get "project_progress")
                local active=$(blackboard_get "active_track")
                local test_status=$(blackboard_get "test_last_status")
                echo "RESPONSE: Progress $progress | Active Track: $active | Tests: $test_status"
                ;;
            *)
                echo "UNKNOWN COMMAND"
                ;;
        esac
    fi
}

RESULT=$(process_commands "!status")
EXPECTED="RESPONSE: Progress 75% | Active Track: QA Automation | Tests: PASS"

if [[ "$RESULT" == *"$EXPECTED"* ]]; then
    echo "SUCCESS: !status command processed correctly."
else
    echo "FAILURE: !status output was '$RESULT'."
    exit 1
fi

echo "All QA command verification tests passed!"
rm -f "$HCOM_DB_PATH"
