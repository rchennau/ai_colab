#!/usr/bin/env bash
# hcom Shared Blackboard (KV Store)
# Provides shared state for agents via hcom.db

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

DB_PATH=$(get_hcom_db_path)

show_usage() {
    cat << EOF
Usage: hcom-kv <command> [args]

Commands:
  set <key> <value>    Store a value
  get <key>            Retrieve a value
  list                 List all keys and values
  delete <key>         Remove a key
  clear                Clear the entire blackboard
EOF
}

[[ $# -lt 1 ]] && { show_usage; exit 1; }

# Check for dependencies
check_sqlite3 || exit 1

# If hcom.db doesn't exist, we can't do much unless we create it ourselves
# But usually hcom handles this.
if [[ ! -f "$DB_PATH" ]]; then
    # Ensure directory exists
    mkdir -p "$(dirname "$DB_PATH")"
    # Create basic structure if it doesn't exist
    sqlite3 "$DB_PATH" "CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT);"
fi

CMD="$1"; shift

case "$CMD" in
    set)
        [[ $# -lt 2 ]] && { echo "Error: Missing key or value"; exit 1; }
        KEY="$1"; shift
        VALUE="$*"
        sqlite3 "$DB_PATH" ".timeout 5000" "INSERT OR REPLACE INTO kv (key, value) VALUES ('$KEY', '$VALUE');"
        ;;
    get)
        [[ $# -lt 1 ]] && { echo "Error: Missing key"; exit 1; }
        KEY="$1"
        sqlite3 "$DB_PATH" ".timeout 5000" "SELECT value FROM kv WHERE key = '$KEY';"
        ;;
    list)
        sqlite3 "$DB_PATH" ".timeout 5000" "SELECT key || ': ' || value FROM kv;"
        ;;
    delete)
        [[ $# -lt 1 ]] && { echo "Error: Missing key"; exit 1; }
        KEY="$1"
        sqlite3 "$DB_PATH" ".timeout 5000" "DELETE FROM kv WHERE key = '$KEY';"
        ;;
    clear)
        sqlite3 "$DB_PATH" ".timeout 5000" "DELETE FROM kv;"
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
