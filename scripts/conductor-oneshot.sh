#!/usr/bin/env bash
# Automated hcom Conductor Agent Workflow (One-shot)
# Monitors project tracks, updates status, and ensures alignment.

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Check for hcom
if ! has_command hcom; then
    echo -e "${RED}Error: hcom is required for the automated conductor workflow.${NC}"
    exit 1
fi

# Agent registration
AGENT_NAME="conductor-$(hostname)-$$"
hcom start --as "$AGENT_NAME" > /dev/null 2>&1 || true
export HCOM_NAME="$AGENT_NAME"

# Thread subscription
hcom events sub --agent "$AGENT_NAME" --thread "plan-sync" --once > /dev/null 2>&1 &
hcom events sub --agent "$AGENT_NAME" --thread "track-updates" > /dev/null 2>&1 &

TRACKS_FILE="conductor/tracks.md"

echo "Conductor Agent [$AGENT_NAME] initialized. Running one-shot update for $TRACKS_FILE."

if [[ -f "$TRACKS_FILE" ]]; then
    # Calculate progress
    TOTAL=$(grep -c "^\- \[.\] \*\*Track:" "$TRACKS_FILE" || echo "0")
    COMPLETE=$(grep -c "^\- \[x\] \*\*Track:" "$TRACKS_FILE" || echo "0")
    
    if [[ $TOTAL -gt 0 ]]; then
        PERCENT=$(( (COMPLETE * 100) / TOTAL ))
    else
        PERCENT=0
    fi

    # Find next ready track (todo/planning)
    NEXT_TRACK=$(grep -m 1 "^\- \[ \] \*\*Track:" "$TRACKS_FILE" | sed 's/^- \[ \] \*\*Track: //;s/\*\*.*//')

    # Update Shared Blackboard
    "$SCRIPT_DIR/hcom-kv" set project_progress "$PERCENT%"
    "$SCRIPT_DIR/hcom-kv" set active_track "${NEXT_TRACK:-None}"
    "$SCRIPT_DIR/hcom-kv" set conductor_last_run "$(date '+%Y-%m-%dT%H:%M:%S%z')"

    # --- Automated Tasking Section ---
    MAX_WORKERS=$("$SCRIPT_DIR/hcom-kv" get conductor_max_workers || echo "1")
    [ -z "$MAX_WORKERS" ] && MAX_WORKERS=1
    
    CURRENT_WORKERS=$(hcom list --names | grep -c "worker-" || echo "0")

    if [ "$CURRENT_WORKERS" -lt "$MAX_WORKERS" ] && [ -n "$NEXT_TRACK" ]; then
        # Convert track name to a slug
        TRACK_SLUG=$(echo "$NEXT_TRACK" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g;s/--\+/-/g;s/^-//;s/-$//')
        
        # Check if this track is already assigned and if that agent is still alive
        ASSIGNED_AGENT=$("$SCRIPT_DIR/hcom-kv" get "track_assigned_$TRACK_SLUG" || true)
        AGENT_ALIVE=false
        if [ -n "$ASSIGNED_AGENT" ]; then
            if hcom list --names | grep -q "\b$ASSIGNED_AGENT\b"; then
                AGENT_ALIVE=true
            fi
        fi

        if [ "$AGENT_ALIVE" = false ]; then
            echo "[$(date +%T)] Assigning new worker for track: $NEXT_TRACK"
            
            # Spawn a headless worker
            SPAWN_OUT=$(hcom 1 gemini --tag worker --headless --go 2>&1 || true)
            
            # Extract agent name
            NEW_AGENT=$(echo "$SPAWN_OUT" | grep "^Names: " | awk '{print $2}' || true)

            if [ -n "$NEW_AGENT" ]; then
                echo "[$(date +%T)] Spawned agent $NEW_AGENT for $TRACK_SLUG"
                "$SCRIPT_DIR/hcom-kv" set "track_assigned_$TRACK_SLUG" "$NEW_AGENT"
                "$SCRIPT_DIR/hcom-kv" set "agent_task_$NEW_AGENT" "$NEXT_TRACK"
                
                # Send initial tasking message
                hcom send "@$NEW_AGENT" --name "$AGENT_NAME" --intent request --thread "task-handoff" -- \
                    "Your task is to implement the following track: $NEXT_TRACK. Please review conductor/tracks.md for specifications and report progress via the blackboard (hcom-kv)."
            fi
        fi
    fi
    # --- End Automated Tasking ---

    # Broadcast status update
    hcom send @all --intent inform --thread "plan-sync" -- "Status: $COMPLETE/$TOTAL tracks complete ($PERCENT%). Next up: ${NEXT_TRACK:-All complete}."
    
    echo "[$(date +%T)] Status updated: $PERCENT%. Next: $NEXT_TRACK"
else
    echo "[$(date +%T)] Warning: $TRACKS_FILE not found."
fi

# Short wait to allow message to be sent
sleep 1
