#!/usr/bin/env bash
# Shared utilities for ai-colab scripts

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if a command exists
has_command() {
    command -v "$1" >/dev/null 2>&1
}

# Check for hcom and warn if missing
check_hcom() {
    if ! has_command hcom; then
        echo -e "${YELLOW}Warning: hcom is not installed.${NC}" >&2
        echo -e "Some features (messaging, status tracking, blackboard) will be disabled." >&2
        echo -e "To install hcom, visit: https://github.com/hcom-org/hcom" >&2
        return 1
    fi
    return 0
}

# Check for sqlite3
check_sqlite3() {
    if ! has_command sqlite3; then
        echo -e "${RED}Error: sqlite3 is not installed.${NC}" >&2
        echo -e "This is required for the Shared Blackboard (hcom-kv)." >&2
        return 1
    fi
    return 0
}

# Cross-platform file modification time
get_file_mtime() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "N/A"
        return
    fi

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS (BSD stat)
        stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file"
    else
        # Linux (GNU stat)
        stat -c %y "$file" | cut -d'.' -f1
    fi
}

# Detect project root
detect_project_root() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [ -f "$dir/conductor/tracks.md" ] || [ -f "$dir/conductor/product.md" ] || [ -d "$dir/.git" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    echo "$PWD"
}

# Get hcom database path
get_hcom_db_path() {
    echo "${HCOM_DB_PATH:-$HOME/.hcom/hcom.db}"
}

# hcom Agent Helpers

register_hcom() {
    local tool_name="$1"
    if has_command hcom; then
        # Use underscore instead of hyphen for hcom 0.7.5 compatibility
        local name="${HCOM_NAME:-${tool_name}_\$\$}"
        export HCOM_NAME="$name"
        
        hcom start --as "$HCOM_NAME" > /dev/null 2>&1 || true
        hcom listen --name "$HCOM_NAME" --timeout 1 > /dev/null 2>&1 || true
        return 0
    fi
    return 1
}

start_heartbeat() {
    if [ -n "${HCOM_NAME:-}" ]; then
        (while true; do 
            hcom listen --name "$HCOM_NAME" --timeout 60 > /dev/null 2>&1 || sleep 60
        done) &
        local pid=$!
        trap "kill $pid 2>/dev/null || true" EXIT
        return 0
    fi
    return 1
}
