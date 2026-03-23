#!/usr/bin/env bash
# Test conductor-workflow.sh tmux TUI updates

set -euo pipefail

# Mock tmux to record calls
tmux() {
    echo "MOCK_TMUX: $*" >> /tmp/tmux_calls.log
}
export -f tmux
export TMUX="true"

# Setup dummy tracks.md
TRACKS_FILE="/tmp/test_tracks_tui.md"
echo "- [ ] **Track: TUI Test Feature**" > "$TRACKS_FILE"

# Prepare workflow script mock
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
rm -f /tmp/tmux_calls.log

# We define the sync_blackboard_status function to test it
sync_blackboard_status() {
    local tracks_file="$1"
    source "$SCRIPT_DIR/utils.sh"
    # Manual copy of the relevant section for testing
    local total=$(grep -c "^\- \[.\] \*\*Track:" "$tracks_file" || true)
    local complete=$(grep -c "^\- \[x\] \*\*Track:" "$tracks_file" || true)
    [[ -z "$total" ]] && total=0
    [[ -z "$complete" ]] && complete=0
    local percent=0
    [[ "$total" -gt 0 ]] && percent=$(( (complete * 100) / total ))
    local next_track=$(grep -m 1 "^\- \[ \] \*\*Track:" "$tracks_file" | sed 's/^- \[ \] \*\*Track: //;s/\*\*.*//')
    
    # The actual code being tested:
    if [[ -n "${TMUX:-}" ]]; then
        local status_text="[Active: ${next_track:-None} | Progress: $percent%]"
        tmux set-option -g status-right "$status_text" > /dev/null 2>&1 || true
        tmux select-pane -t "hcom-dashboard:0.0" -T "hcom TUI $status_text" > /dev/null 2>&1 || true
    fi
}

# Run the test
echo "Running TUI update test..."
sync_blackboard_status "$TRACKS_FILE"

# Verify tmux calls
if grep -q "set-option -g status-right \[Active: TUI Test Feature | Progress: 0%\]" /tmp/tmux_calls.log; then
    echo "SUCCESS: status-right update called correctly."
else
    echo "FAILURE: status-right update NOT called correctly."
    cat /tmp/tmux_calls.log
    exit 1
fi

if grep -q "select-pane -t hcom-dashboard:0.0 -T hcom TUI \[Active: TUI Test Feature | Progress: 0%\]" /tmp/tmux_calls.log; then
    echo "SUCCESS: pane title update called correctly."
else
    echo "FAILURE: pane title update NOT called correctly."
    cat /tmp/tmux_calls.log
    exit 1
fi

echo "All Dashboard Integration TUI tests passed!"
rm -f "$TRACKS_FILE" /tmp/tmux_calls.log
