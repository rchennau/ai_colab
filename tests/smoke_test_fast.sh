#!/usr/bin/env bash
# ai-colab Fast Smoke Test (skips install)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMOKE_LOG="$PROJECT_ROOT/logs/smoke_test_fast.log"
echo "--- Fast Smoke Test Started: $(date) ---" > "$SMOKE_LOG"

log() { echo -e "${BLUE}[SMOKE]${NC} $1" | tee -a "$SMOKE_LOG"; }
pass() { echo -e "${GREEN}✓ PASS:${NC} $1" | tee -a "$SMOKE_LOG"; }
fail() { echo -e "${RED}✗ FAIL:${NC} $1" | tee -a "$SMOKE_LOG"; exit 1; }

log "Step 1: Preparing hcom state..."
sqlite3 "$HOME/.hcom/hcom.db" "DELETE FROM kv;" 2>/dev/null || true
sqlite3 "$HOME/.hcom/hcom.db" "DELETE FROM events;" 2>/dev/null || true
rm -f "$PROJECT_ROOT/smoke_output.txt"
pass "State cleared"

log "Step 2: Injecting smoke command via SQL injection (Pre-emptive)..."
# Inject with field names that process_commands expects: from, text, thread
# The conductor's extract_event_value looks for these field names in the data
SQL_DATA='{"from":"smoke_trigger","text":"!smoke","thread":"smoke","scope":"global"}'
sqlite3 "$HOME/.hcom/hcom.db" "INSERT INTO events (timestamp, type, instance, data) VALUES (datetime('now'), 'message', 'smoke_trigger', '$SQL_DATA');"

log "Step 3: Launching Conductor in background..."
export CONDUCTOR_INTERVAL=5
export CI=true
bash "$PROJECT_ROOT/scripts/conductor-workflow.sh" >> "$SMOKE_LOG" 2>&1 &
CONDUCTOR_PID=$!

cleanup() {
    log "Cleaning up..."
    kill $CONDUCTOR_PID 2>/dev/null || true
}
trap cleanup EXIT

log "Waiting for execution (60s)..."
for i in {1..60}; do
    if [[ -f "$PROJECT_ROOT/smoke_output.txt" ]]; then
        RESULT=$(cat "$PROJECT_ROOT/smoke_output.txt")
        if [[ "$RESULT" == *"Hello from ai-colab Smoke Test"* ]]; then
            pass "Fast Smoke Test Executed successfully!"
            log "Output: $RESULT"
            exit 0
        fi
    fi
    if (( i % 10 == 0 )); then
        log "  ... still waiting ($i/60s)..."
    fi
    sleep 1
done

log "--- FINAL DEBUG STATE ---"
log "KV Table entries:"
sqlite3 "$HOME/.hcom/hcom.db" "SELECT * FROM kv;" | tee -a "$SMOKE_LOG"
log "Events Table entries:"
sqlite3 "$HOME/.hcom/hcom.db" "SELECT * FROM events;" | tee -a "$SMOKE_LOG"

fail "Fast Smoke Test failed to produce output file within 30s."
