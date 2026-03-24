#!/usr/bin/env bash
# Shared utilities for ai-colab scripts

# Ensure ~/.local/bin is in PATH for hcom
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

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

# Blackboard Helpers (hcom-kv)

blackboard_set() {
    local key="$1"
    local value="$2"
    local db_path=$(get_hcom_db_path)

    # Ensure directory exists
    mkdir -p "$(dirname "$db_path")"
    
    # Create basic structure if it doesn't exist
    sqlite3 "$db_path" "CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT);" || {
        echo -e "${RED}Error: Failed to access blackboard at $db_path${NC}" >&2
        return 1
    }

    sqlite3 "$db_path" ".timeout 5000" "INSERT OR REPLACE INTO kv (key, value) VALUES ('$key', '$value');"
}

blackboard_get() {
    local key="$1"
    local db_path=$(get_hcom_db_path)

    if [[ ! -f "$db_path" ]]; then
        return 0
    fi

    sqlite3 "$db_path" ".timeout 5000" "SELECT value FROM kv WHERE key = '$key';"
}

# hcom Agent Helpers

register_hcom() {
    local tool_name="$1"
    if has_command hcom; then
        # Use underscore instead of hyphen for hcom 0.7.5 compatibility
        local name="${HCOM_NAME:-${tool_name}_\$\$}"
        export HCOM_NAME="$name"

        # Register the agent with hcom and keep it persistent
        # We don't start a background listen here because it overwrites status
        hcom start --as "$HCOM_NAME" > /dev/null 2>&1 || true
        return 0
    fi
    return 1
}

start_heartbeat() {
    local tool_name="${1:-agent}"
    if [ -n "${HCOM_NAME:-}" ]; then
        # Continuous heartbeat via 'hcom start' in background.
        # This keeps the status 'ready' in TUI without stealing messages like 'listen' would.
        # We use a 10s interval to ensure status stays fresh.
        (
            while true; do
                hcom start --as "$HCOM_NAME" > /dev/null 2>&1 || true
                sleep 10
            done
        ) &
        HEARTBEAT_PID=$!
        return 0
    fi
    return 1
}
