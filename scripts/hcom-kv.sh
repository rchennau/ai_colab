#!/usr/bin/env bash
# hcom Shared Blackboard (KV Store)
# Provides shared state for agents via hcom.db

set -euo pipefail

DB_PATH="/home/rchennau/.hcom/hcom.db"

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
