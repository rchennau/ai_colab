#!/usr/bin/env bash
# Test hcom-profiler.sh

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../../scripts && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Mock/Override DB_PATH for testing
export HCOM_DB_PATH="/tmp/test_hcom_profiler.db"
rm -f "$HCOM_DB_PATH"

# Mock gemini command
gemini() {
    echo "Profiling result: 1234 cycles."
}
export -f gemini

# Mock hcom command
hcom() {
    echo "Mock hcom: $*"
}
export -f hcom

# Create a dummy file to profile
DUMMY_FILE="/tmp/test_profile_file.asm"
echo "LDA #0" > "$DUMMY_FILE"

# 1. Test Profiling
echo "Testing profiling..."
bash "$SCRIPT_DIR/../modules/atari-8bit/scripts/hcom-profiler.sh" "$DUMMY_FILE" > /dev/null

BLACKBOARD_KEY="perf_$(echo "$DUMMY_FILE" | tr '/' '_')"
RESULT=$(blackboard_get "$BLACKBOARD_KEY")

if [[ "$RESULT" == *"Profiling result"* ]]; then
    echo "SUCCESS: Profiling result stored in blackboard."
else
    echo "FAILURE: Result is '$RESULT', expected it to contain 'Profiling result'."
    exit 1
fi

echo "All profiler tests passed!"
rm -f "$HCOM_DB_PATH" "$DUMMY_FILE"
