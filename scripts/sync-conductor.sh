#!/usr/bin/env bash
# Sync Conductor Plan across all active hcom agents.
# Usage: hcom run sync-conductor [tracks.md] [product.md]
set -euo pipefail

NAME_FLAG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME_FLAG="$2"; shift 2 ;;
    *) break ;;
  esac
done

# Use assigned name or default to master-sync
AGENT_NAME="${NAME_FLAG:-master-sync}"
hcom start --as "$AGENT_NAME" > /dev/null 2>&1 || true

TRACKS="${1:-conductor/tracks.md}"
PRODUCT="${2:-conductor/product.md}"

if [[ ! -f "$TRACKS" ]]; then
    echo "Error: $TRACKS not found."
    exit 1
fi

echo "Preparing Plan Sync Bundle..."
# Get a recent event ID to satisfy bundle requirements
LAST_EV=$(hcom events --last 1 | grep -oP '"id":\K\d+')

# Broadcast sync message with inline bundle
hcom send --name "$AGENT_NAME" \
    --intent inform \
    --thread "plan-sync" \
    --title "Plan Synced" \
    --description "The Conductor plan has been synchronized to the latest state." \
    --files "$TRACKS,$PRODUCT" \
    --events "$LAST_EV" \
    --transcript "1:normal" \
    -- "The Conductor plan (tracks.md, product.md) has been updated. Please sync your internal state."

echo "Sync message broadcast to all agents in thread 'plan-sync'."
