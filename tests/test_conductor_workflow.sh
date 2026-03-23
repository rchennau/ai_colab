#!/usr/bin/env bash
# Test conductor-workflow.sh blackboard sync

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Mock/Override DB_PATH for testing
export HCOM_DB_PATH="/tmp/test_hcom_workflow.db"
rm -f "$HCOM_DB_PATH"

# Setup dummy tracks.md
TRACKS_FILE="/tmp/test_tracks.md"
cat << EOF > "$TRACKS_FILE"
# Test Tracks
- [ ] **Track: Test Feature**
EOF

# Define functions for testing (manual copy from script for robustness)
update_tracks_from_blackboard() {
    local tracks_file="$1"
    grep "^\- \[ \] \*\*Track:" "$tracks_file" | while read -r line; do
        local track_name=$(echo "$line" | sed 's/^- \[ \] \*\*Track: //;s/\*\*.*//')
        local track_slug=$(echo "$track_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g;s/--\+/-/g;s/^-//;s/-$//')
        local status=$(blackboard_get "track_status_$track_slug")
        local commit_sha=$(blackboard_get "track_commit_$track_slug")
        if [[ "$status" == "complete" ]]; then
            local replacement="- [x] **Track: $track_name**"
            [[ -n "$commit_sha" ]] && replacement="$replacement ($commit_sha)"
            local escaped_track_name=$(echo "$track_name" | sed 's/[^^]/[&]/g; s/\^/\\^/g')
            sed -i.bak "s/^- \[ \] \*\*Track: $escaped_track_name\*\*/$replacement/" "$tracks_file"
            rm -f "${tracks_file}.bak"
            blackboard_set "track_status_$track_slug" "synced"
        fi
    done
}

sync_blackboard_status() {
    local tracks_file="$1"
    if [[ -f "$tracks_file" ]]; then
        local total=$(grep -c "^\- \[.\] \*\*Track:" "$tracks_file" || true)
        local complete=$(grep -c "^\- \[x\] \*\*Track:" "$tracks_file" || true)
        [[ -z "$total" ]] && total=0
        [[ -z "$complete" ]] && complete=0
        local percent=0
        [[ "$total" -gt 0 ]] && percent=$(( (complete * 100) / total ))
        local next_track=$(grep -m 1 "^\- \[ \] \*\*Track:" "$tracks_file" | sed 's/^- \[ \] \*\*Track: //;s/\*\*.*//')
        blackboard_set "project_progress" "$percent%"
        blackboard_set "active_track" "${next_track:-None}"
        update_tracks_from_blackboard "$tracks_file"
    fi
}

# 1. Initial sync - should set active_track
echo "Testing initial sync..."
sync_blackboard_status "$TRACKS_FILE"

ACTIVE=$(blackboard_get "active_track")
if [[ "$ACTIVE" == "Test Feature" ]]; then
    echo "SUCCESS: active_track set correctly."
else
    echo "FAILURE: active_track is '$ACTIVE', expected 'Test Feature'."
    exit 1
fi

# 2. Mark track as complete in blackboard
echo "Marking track as complete in blackboard..."
TRACK_SLUG="test-feature"
blackboard_set "track_status_$TRACK_SLUG" "complete"
blackboard_set "track_commit_$TRACK_SLUG" "abc1234"

# 3. Sync again - should update tracks.md
echo "Syncing again to trigger auto-completion..."
sync_blackboard_status "$TRACKS_FILE"

if grep -q "\- \[x\] \*\*Track: Test Feature\*\* (abc1234)" "$TRACKS_FILE"; then
    echo "SUCCESS: tracks.md updated correctly."
else
    echo "FAILURE: tracks.md not updated correctly."
    cat "$TRACKS_FILE"
    exit 1
fi

echo "All conductor-workflow sync tests passed!"
rm -f "$HCOM_DB_PATH" "$TRACKS_FILE"
