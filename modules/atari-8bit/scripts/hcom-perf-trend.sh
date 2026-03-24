#!/usr/bin/env bash
# hcom Performance Trending Tool
# Analyzes historical performance data from the blackboard database.

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/utils.sh"

ROUTINE_NAME="${1:-}"
[[ -z "$ROUTINE_NAME" ]] && { echo "Usage: hcom-perf-trend.sh <routine_name>"; exit 1; }

DB_PATH=$(get_hcom_db_path)

log_info "Analyzing performance trends for: $ROUTINE_NAME"

# Fetch last two entries
RESULTS=$(sqlite3 "$DB_PATH" "SELECT cycles, timestamp FROM performance WHERE routine = '$ROUTINE_NAME' ORDER BY timestamp DESC LIMIT 2;")

if [[ -z "$RESULTS" ]]; then
    echo "No performance data found for $ROUTINE_NAME."
    exit 0
fi

# Count rows
COUNT=$(echo "$RESULTS" | wc -l | tr -d ' ')

if [[ "$COUNT" -lt 2 ]]; then
    LATEST_CYCLES=$(echo "$RESULTS" | head -n 1 | cut -d'|' -f1)
    echo "First data point for $ROUTINE_NAME: $LATEST_CYCLES cycles."
    exit 0
fi

# Extract values
LATEST_CYCLES=$(echo "$RESULTS" | sed -n '1p' | cut -d'|' -f1)
PREV_CYCLES=$(echo "$RESULTS" | sed -n '2p' | cut -d'|' -f1)

# Calculate difference
DIFF=$((LATEST_CYCLES - PREV_CYCLES))
PCT_CHANGE=$(echo "scale=2; ($DIFF * 100) / $PREV_CYCLES" | bc)

echo "--- Trend Report: $ROUTINE_NAME ---"
echo "Latest: $LATEST_CYCLES cycles"
echo "Previous: $PREV_CYCLES cycles"

if [[ "$DIFF" -lt 0 ]]; then
    log_success "Improvement: ${PCT_CHANGE#-} % reduction in cycles."
elif [[ "$DIFF" -gt 0 ]]; then
    log_warn "Regression: $PCT_CHANGE % increase in cycles."
else
    echo "No change in performance."
fi

# Integrated Alert Logic for regression
if (( $(echo "$PCT_CHANGE > 5.0" | bc -l) )); then
    hcom send @all --intent inform --thread "visual-debug" -- "CRITICAL PERF REGRESSION: $ROUTINE_NAME increased by $PCT_CHANGE% ($PREV_CYCLES -> $LATEST_CYCLES cycles)."
fi
