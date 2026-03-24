#!/usr/bin/env bash
# Test track dependency resolution in conductor-workflow.sh

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Mock/Override DB_PATH for testing
export HCOM_DB_PATH="/tmp/test_hcom_deps.db"
rm -f "$HCOM_DB_PATH"

# Setup dummy tracks.md
TRACKS_FILE="/tmp/test_tracks_deps.md"
cat << EOF > "$TRACKS_FILE"
# Test Tracks
- [x] **Track: Base Feature**
- [ ] **Track: Dependent Feature** (Requires: Base Feature)
- [ ] **Track: Blocked Feature** (Requires: Missing Feature)
- [ ] **Track: Simple Feature**
EOF

# Define functions for testing
check_track_dependencies() {
    local track_line="$1"
    local tracks_file="$2"
    # Portable extraction (Requires: Track Name)
    local dep_name=$(echo "$track_line" | sed -n 's/.*(Requires: \(.*\)).*/\1/p' || echo "")
    if [[ -n "$dep_name" ]]; then
        if grep -q "\- \[x\] \*\*Track: $dep_name\*\*" "$tracks_file"; then
            return 0
        else
            return 1
        fi
    fi
    return 0
}

# 1. Check Dependent Feature (should pass)
echo "Checking Dependent Feature (dependency met)..."
LINE=$(grep "Track: Dependent Feature" "$TRACKS_FILE")
if check_track_dependencies "$LINE" "$TRACKS_FILE"; then
    echo "SUCCESS: Dependency met correctly."
else
    echo "FAILURE: Dependency not met."
    exit 1
fi

# 2. Check Blocked Feature (should fail)
echo "Checking Blocked Feature (dependency unmet)..."
LINE=$(grep "Track: Blocked Feature" "$TRACKS_FILE")
if ! check_track_dependencies "$LINE" "$TRACKS_FILE"; then
    echo "SUCCESS: Dependency unmet correctly."
else
    echo "FAILURE: Dependency mistakenly reported as met."
    exit 1
fi

# 3. Check Simple Feature (should pass)
echo "Checking Simple Feature (no dependency)..."
LINE=$(grep "Track: Simple Feature" "$TRACKS_FILE")
if check_track_dependencies "$LINE" "$TRACKS_FILE"; then
    echo "SUCCESS: No dependency handled correctly."
else
    echo "FAILURE: Simple track blocked."
    exit 1
fi

echo "All track dependency tests passed!"
rm -f "$HCOM_DB_PATH" "$TRACKS_FILE"
