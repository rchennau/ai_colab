#!/usr/bin/env bash
# Automated hcom Conductor Agent Workflow
# Monitors project tracks, updates status, and ensures alignment.

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Check for dependencies
check_hcom || exit 1
check_sqlite3 || exit 1

# Configuration
TRACKS_FILE="conductor/tracks.md"
INTERVAL=${CONDUCTOR_INTERVAL:-60} # Default to 60 seconds

# Agent registration
export HCOM_NAME="conductor_$(hostname | tr "[:upper:]" "[:lower:]" | tr "." "_")_$$"
register_hcom "conductor" || true

# Thread subscription
hcom events sub --agent "$HCOM_NAME" --thread "plan-sync" --once > /dev/null 2>&1 &
hcom events sub --agent "$HCOM_NAME" --thread "track-updates" > /dev/null 2>&1 &

update_tracks_from_blackboard() {
    local tracks_file="$1"
    
    # List all tracks in the file
    grep "^\- \[ \] \*\*Track:" "$tracks_file" | while read -r line; do
        local track_name=$(echo "$line" | sed 's/^- \[ \] \*\*Track: //;s/\*\*.*//')
        local track_slug=$(echo "$track_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g;s/--\+/-/g;s/^-//;s/-$//')
        
        # Check blackboard for status
        local status=$(blackboard_get "track_status_$track_slug")
        local commit_sha=$(blackboard_get "track_commit_$track_slug")
        
        if [[ "$status" == "complete" ]]; then
            echo "[$(date +%T)] Auto-completing track: $track_name (via blackboard)"
            
            # Update tracks.md status to [x]
            # If we have a commit SHA, append it
            local replacement="- [x] **Track: $track_name**"
            [[ -n "$commit_sha" ]] && replacement="$replacement ($commit_sha)"
            
            # Escape track name for sed
            local escaped_track_name=$(echo "$track_name" | sed 's/[^^]/[&]/g; s/\^/\\^/g')
            sed -i.bak "s/^- \[ \] \*\*Track: $escaped_track_name\*\*/$replacement/" "$tracks_file"
            rm -f "${tracks_file}.bak"
            
            # Clear blackboard status to avoid re-processing
            blackboard_set "track_status_$track_slug" "synced"
            
            # Broadcast the update
            hcom send @all --intent inform --thread "plan-sync" -- "Track completed: $track_name"
        fi
    done
}

sync_blackboard_status() {
    local tracks_file="$1"
    
    if [[ -f "$tracks_file" ]]; then
        # Calculate progress
        local total=$(grep -c "^\- \[.\] \*\*Track:" "$tracks_file" || true)
        local complete=$(grep -c "^\- \[x\] \*\*Track:" "$tracks_file" || true)
        
        # Ensure they are numeric
        [[ -z "$total" ]] && total=0
        [[ -z "$complete" ]] && complete=0
        
        local percent=0
        [[ "$total" -gt 0 ]] && percent=$(( (complete * 100) / total ))

        # Find next ready track
        local next_track=$(grep -m 1 "^\- \[ \] \*\*Track:" "$tracks_file" | sed 's/^- \[ \] \*\*Track: //;s/\*\*.*//')

        # Update Shared Blackboard
        blackboard_set "project_progress" "$percent%"
        blackboard_set "active_track" "${next_track:-None}"
        blackboard_set "conductor_last_run" "$(date '+%Y-%m-%dT%H:%M:%S%z')"
        
        # Update TMUX status bar and pane title if in a session
        if [[ -n "${TMUX:-}" ]]; then
            local status_text="[Active: ${next_track:-None} | Progress: $percent%]"
            # Status right for global view
            tmux set-option -g status-right "$status_text" > /dev/null 2>&1 || true
            # Update hcom pane title for focus
            tmux select-pane -t "hcom-dashboard:0.0" -T "hcom TUI $status_text" > /dev/null 2>&1 || true
        fi
        
        # Sync tracks back from blackboard
        update_tracks_from_blackboard "$tracks_file"
        
        # Broadcast status update
        hcom send @all --intent inform --thread "plan-sync" -- "Status: $complete/$total tracks complete ($percent%). Next up: ${next_track:-All complete}."
        
        echo "[$(date +%T)] Status updated: $percent%. Next: $next_track"
    else
        echo "[$(date +%T)] Warning: $tracks_file not found."
    fi
}

spawn_workers() {
    local tracks_file="$1"
    local next_track=$(grep -m 1 "^\- \[ \] \*\*Track:" "$tracks_file" | sed 's/^- \[ \] \*\*Track: //;s/\*\*.*//')
    
    [[ -z "$next_track" ]] && return

    local max_workers=$(blackboard_get "conductor_max_workers")
    [[ -z "$max_workers" ]] && max_workers=1
    
    local current_workers=$(hcom list --names | grep -c "worker-" || true)

    if [[ "$current_workers" -lt "$max_workers" ]]; then
        local track_slug=$(echo "$next_track" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g;s/--\+/-/g;s/^-//;s/-$//')
        
        local assigned_agent=$(blackboard_get "track_assigned_$track_slug")
        local agent_alive=false
        if [[ -n "$assigned_agent" ]]; then
            if hcom list --names | grep -q "\b$assigned_agent\b"; then
                agent_alive=true
            fi
        fi

        if [[ "$agent_alive" == false ]]; then
            echo "[$(date +%T)] Assigning new worker for track: $next_track"
            
            local spawn_out=$(hcom 1 gemini --tag worker --headless --go 2>&1 || true)
            local new_agent=$(echo "$spawn_out" | grep "^Names: " | awk '{print $2}' || true)

            if [[ -n "$new_agent" ]]; then
                echo "[$(date +%T)] Spawned agent $new_agent for $track_slug"
                blackboard_set "track_assigned_$track_slug" "$new_agent"
                blackboard_set "agent_task_$new_agent" "$next_track"
                
                hcom send "@$new_agent" --name "$HCOM_NAME" --intent request --thread "task-handoff" -- \
                    "Your task is to implement the following track: $next_track. Please review conductor/tracks.md for specifications and report progress via the blackboard (hcom-kv)."
            fi
        fi
    fi
}

echo "Conductor Agent [$HCOM_NAME] initialized. Monitoring $TRACKS_FILE every $INTERVAL seconds."

# Start heartbeat in background
start_heartbeat || true

while true; do
    sync_blackboard_status "$TRACKS_FILE"
    spawn_workers "$TRACKS_FILE"
    
    # Wait for next interval or interrupt
    hcom listen --timeout "$INTERVAL" --name "$HCOM_NAME" > /dev/null 2>&1 || sleep "$INTERVAL"
done
