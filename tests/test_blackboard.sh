#!/usr/bin/env bash
# Test blackboard functions in scripts/utils.sh
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Mock/Override DB_PATH for testing
export HCOM_DB_PATH="/tmp/test_hcom.db"
rm -f "$HCOM_DB_PATH"

# Test blackboard_get with non-existent DB
echo "Testing blackboard_get with non-existent DB..."
RESULT=$(blackboard_get "missing_db_key")
if [[ -z "$RESULT" ]]; then
    echo "SUCCESS: blackboard_get returned empty for non-existent DB."
else
    echo "FAILURE: blackboard_get returned '$RESULT' for non-existent DB, expected empty."
    exit 1
fi

# Test blackboard_set
echo "Testing blackboard_set..."
blackboard_set "test_key" "test_value"

# Test blackboard_get
echo "Testing blackboard_get..."
RESULT=$(blackboard_get "test_key")
if [[ "$RESULT" == "test_value" ]]; then
    echo "SUCCESS: blackboard_get returned expected value."
else
    echo "FAILURE: blackboard_get returned '$RESULT', expected 'test_value'."
    exit 1
fi

# Test non-existent key
echo "Testing blackboard_get with non-existent key..."
RESULT=$(blackboard_get "missing_key")
if [[ -z "$RESULT" ]]; then
    echo "SUCCESS: blackboard_get returned empty for missing key."
else
    echo "FAILURE: blackboard_get returned '$RESULT' for missing key, expected empty."
    exit 1
fi

# Performance / Stress Test
echo "Testing performance (100 sequential writes)..."
start_time=$(date +%s)
for i in {1..100}; do
    blackboard_set "key_$i" "value_$i"
done
end_time=$(date +%s)
duration=$((end_time - start_time))
echo "100 writes completed in ${duration}s."

# Verify last write
RESULT=$(blackboard_get "key_100")
if [[ "$RESULT" == "value_100" ]]; then
    echo "SUCCESS: Performance test verification passed."
else
    echo "FAILURE: Performance test verification failed."
    exit 1
fi

echo "All blackboard tests passed!"
rm -f "$HCOM_DB_PATH"
