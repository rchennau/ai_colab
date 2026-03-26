#!/usr/bin/env bash
# Test hcom performance trending

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../../scripts && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Mock/Override DB_PATH for testing
export HCOM_DB_PATH="/tmp/test_hcom_perf_trend.db"
rm -f "$HCOM_DB_PATH"

# Setup table
sqlite3 "$HCOM_DB_PATH" "CREATE TABLE IF NOT EXISTS performance (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp TEXT, routine TEXT, cycles INTEGER, commit_sha TEXT);"

# 1. Insert dummy data
echo "Inserting historical data..."
sqlite3 "$HCOM_DB_PATH" "INSERT INTO performance (timestamp, routine, cycles, commit_sha) VALUES (datetime('now', '-1 hour'), 'test_routine', 1000, 'sha1');"
sqlite3 "$HCOM_DB_PATH" "INSERT INTO performance (timestamp, routine, cycles, commit_sha) VALUES (datetime('now'), 'test_routine', 900, 'sha2');"

# 2. Test Trending
echo "Testing trend report..."
REPORT=$(bash "$SCRIPT_DIR/../modules/atari-8bit/scripts/hcom-perf-trend.sh" "test_routine")

if [[ "$REPORT" == *"Improvement"* ]]; then
    echo "SUCCESS: Trend identified improvement."
else
    echo "FAILURE: Trend report: '$REPORT'."
    exit 1
fi

# 3. Test Regression Alert
echo "Testing regression alert..."
sqlite3 "$HCOM_DB_PATH" "INSERT INTO performance (timestamp, routine, cycles, commit_sha) VALUES (datetime('now', '+1 hour'), 'test_routine', 1100, 'sha3');"

# Mock hcom to avoid sending real messages
hcom() {
    echo "MOCK HCOM: $*"
}
export -f hcom

REPORT=$(bash "$SCRIPT_DIR/../modules/atari-8bit/scripts/hcom-perf-trend.sh" "test_routine")

if [[ "$REPORT" == *"Regression"* ]]; then
    echo "SUCCESS: Trend identified regression."
else
    echo "FAILURE: Trend report: '$REPORT'."
    exit 1
fi

echo "All performance trending tests passed!"
rm -f "$HCOM_DB_PATH"
