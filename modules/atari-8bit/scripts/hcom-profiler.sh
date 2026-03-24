#!/usr/bin/env bash
# hcom Atari Performance Profiler
# Analyzes assembly code for cycle counts and performance bottlenecks.

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/utils.sh"

FILE_PATH="$1"
[[ -z "$FILE_PATH" ]] && { echo "Usage: hcom-profiler.sh <file_path>"; exit 1; }
[[ ! -f "$FILE_PATH" ]] && { echo "Error: File not found: $FILE_PATH"; exit 1; }

echo "Running performance profile for: $FILE_PATH..."

# Use Gemini to call count_cycles (via atari-dev-agent MCP)
if has_command gemini; then
    # We'll use a specific prompt that triggers the count_cycles tool
    ANALYSIS=$(gemini --model gemini-3.0 --headless --prompt "Count the 6502 cycles for the assembly routines in this file: $FILE_PATH. Content:
$(cat "$FILE_PATH")" 2>&1)
else
    ANALYSIS="Gemini CLI not found. Manual profiling required."
fi

# Update Blackboard
BLACKBOARD_KEY="perf_$(echo "$FILE_PATH" | tr '/' '_')"
blackboard_set "$BLACKBOARD_KEY" "$(echo "$ANALYSIS" | head -n 1 | cut -c1-50)..."

# Persistent History
DB_PATH=$(get_hcom_db_path)
sqlite3 "$DB_PATH" "CREATE TABLE IF NOT EXISTS performance (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp TEXT, routine TEXT, cycles INTEGER, commit_sha TEXT);"

COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "no-git")
ROUTINE_NAME=$(basename "$FILE_PATH")
# Extract cycles from Gemini analysis (regex search for digits followed by 'cycles')
CYCLES=$(echo "$ANALYSIS" | grep -oE '[0-9]+ cycles' | head -n 1 | awk '{print $1}' || echo "0")

if [[ -n "$CYCLES" && "$CYCLES" != "0" ]]; then
    sqlite3 "$DB_PATH" "INSERT INTO performance (timestamp, routine, cycles, commit_sha) VALUES (datetime('now'), '$ROUTINE_NAME', $CYCLES, '$COMMIT_SHA');"
    log_success "Stored performance data: $CYCLES cycles for $ROUTINE_NAME"
fi

# Broadcast to team
hcom send @all --intent inform --thread "visual-debug" -- \
    "Performance Profile: $FILE_PATH. Result: $ANALYSIS"

echo "$ANALYSIS"
