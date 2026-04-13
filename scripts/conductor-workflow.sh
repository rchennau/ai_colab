#!/usr/bin/env bash
# Automated hcom Conductor Agent Workflow
# Monitors project tracks, updates status, and ensures alignment.
# Now with dynamic module support for extensible commands and features.

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Check for dependencies
check_hcom || exit 1
check_sqlite3 || exit 1

# 1. Project Detection
PROJECT_ROOT=$(detect_project_root 2>/dev/null || dirname "$SCRIPT_DIR")
TRACKS_FILE="$PROJECT_ROOT/conductor/tracks.md"
INTERVAL=${CONDUCTOR_INTERVAL:-60} # Default to 60 seconds
TEST_INTERVAL=900 # 15 minutes
LAST_TEST_RUN=0
# Tracking variables for status broadcasts to avoid noise
LAST_BROADCAST_PCT=""
LAST_BROADCAST_TRACK=""
LAST_BROADCAST_TIME=0
# Initialize last event ID from persistent cursor (resilient to restart)
LAST_EVENT_ID=$(conductor_get_event_cursor)

# Start time for uptime calculation
CONDUCTOR_START_TS=$(date +%s)

# Agent registration
export HCOM_NAME="conductor_$(hostname | tr "[:upper:]" "[:lower:]" | tr "." "_")_$$"

log_info "Registering as $HCOM_NAME..."
# Force identity creation/verification non-interactively
timeout 10s hcom start --as "$HCOM_NAME" < /dev/null > /dev/null 2>&1 || true

# Wait for hcom to be ready
RETRY=0
while ! hcom status --name "$HCOM_NAME" >/dev/null 2>&1 && [ $RETRY -lt 5 ]; do
    log_warn "Waiting for hcom identity $HCOM_NAME to be ready..."
    sleep 2
    timeout 10s hcom start --as "$HCOM_NAME" < /dev/null > /dev/null 2>&1 || true
    RETRY=$((RETRY+1))
done

if ! hcom status --name "$HCOM_NAME" >/dev/null 2>&1; then
    log_error "Failed to initialize hcom identity. Continuing anyway..."
fi

register_hcom "conductor" || true
start_heartbeat "conductor" || true

cleanup() {
    if [ -n "${HEARTBEAT_PID:-}" ]; then
        kill "$HEARTBEAT_PID" 2>/dev/null || true
    fi
    if [ -n "${HCOM_LISTENER_PID:-}" ]; then
        kill "$HCOM_LISTENER_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Thread subscription
hcom events sub --agent "$HCOM_NAME" --thread "plan-sync" --once > /dev/null 2>&1 &
hcom events sub --agent "$HCOM_NAME" --thread "track-updates" > /dev/null 2>&1 &

# ============================================
# Module System Integration
# ============================================

# Check if a module is active
# Usage: is_module_active "atari-8bit"
is_module_active() {
    local module_id="$1"
    local env_var_name=$(echo "$module_id" | tr '[:lower:]-' '[:upper:]_')
    local env_var="ENABLE_${env_var_name}"
    [[ "${!env_var:-}" == "true" ]]
}

commit_track_changes() {
    local track_slug="$1"
    local track_name="$2"
    local branch=$(blackboard_get "track_branch_$track_slug")
    
    # Check if we are in a git repo
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        return 1
    fi
    
    # If a branch was used, ensure we are on it
    if [[ -n "$branch" ]]; then
        git checkout "$branch" > /dev/null 2>&1
    fi
    
    log_info "Committing changes for track: $track_name"
    git add .
    
    if git commit -m "Auto-commit: Completed track $track_name" > /dev/null 2>&1; then
        local sha=$(git rev-parse --short HEAD)
        log_success "Created commit: $sha"
        blackboard_set "track_commit_$track_slug" "$sha"
        
        # If we were on a branch, switch back to previous (main)
        if [[ -n "$branch" ]]; then
            git checkout - > /dev/null 2>&1
        fi
        return 0
    else
        log_warn "No changes to commit for track: $track_name"
        return 0 # Not an error, just nothing to do
    fi
}

merge_track_pr() {
    local track_slug="$1"
    local track_name="$2"
    local branch=$(blackboard_get "track_branch_$track_slug")
    local commit_sha=$(blackboard_get "track_commit_$track_slug")
    
    # Check if we are in a git repo
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        return 1
    fi
    
    # Switch to main
    git checkout main > /dev/null 2>&1
    
    log_info "Merging track branch: $branch"
    if git merge "$branch" --no-ff -m "Merge track: $track_name ($track_slug)" > /dev/null 2>&1; then
        log_success "Successfully merged $track_name"
        git branch -d "$branch" > /dev/null 2>&1
        return 0
    else
        log_error "Merge conflict while merging $track_name. Please resolve manually."
        return 1
    fi
}

create_track_branch() {
    local track_slug="$1"
    local branch_name="track/$track_slug"
    
    # Check if we are in a git repo
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        return 1
    fi
    
    # Check if branch already exists
    if git rev-parse --verify "$branch_name" > /dev/null 2>&1; then
        log_info "Branch $branch_name already exists."
    else
        log_info "Creating new branch: $branch_name"
        git checkout -b "$branch_name" > /dev/null 2>&1
        git checkout main > /dev/null 2>&1
    fi
    
    blackboard_set "track_branch_$track_slug" "$branch_name"
    return 0
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
            local test_status=$(blackboard_get "test_last_status" || echo "N/A")
            local status_text="[Active: ${next_track:-None} | Progress: $percent% | Tests: $test_status]"
            # Status right for global view
            tmux set-option -g status-right "$status_text" > /dev/null 2>&1 || true
            # Update hcom pane title for focus
            tmux select-pane -t "hcom-dashboard:0.0" -T "hcom TUI $status_text" > /dev/null 2>&1 || true
        fi
        
        # Sync tracks back from blackboard
        update_tracks_from_blackboard "$tracks_file"
        
        # Smart Status Broadcast: Only send if something changed or 10 mins passed
        local current_time=$(date +%s)
        if [[ "$percent" != "$LAST_BROADCAST_PCT" || "$next_track" != "$LAST_BROADCAST_TRACK" || $((current_time - LAST_BROADCAST_TIME)) -gt 600 ]]; then
            log_info "Broadcasting status to all agents..."
            hcom send --name "$HCOM_NAME" --intent inform --thread "plan-sync" -- "Status: $complete/$total tracks complete ($percent%). Next up: ${next_track:-All complete}." || true

            LAST_BROADCAST_PCT="$percent"
            LAST_BROADCAST_TRACK="$next_track"
            LAST_BROADCAST_TIME=$current_time
            log_info "Broadcasted status update: $percent%"
        fi
        
        log_info "Status checked: $percent%. Next: $next_track"
    else
        log_warn "$tracks_file not found."
    fi
}

check_track_dependencies() {
    local track_line="$1"
    local tracks_file="$2"
    
    # Extract dependency if exists: (Requires: Track Name)
    local dep=$(echo "$track_line" | sed -n 's/.*(Requires: \(.*\)).*/\1/p')
    if [[ -n "$dep" ]]; then
        # Check if the required track is complete
        if ! grep -q "^\- \[x\] \*\*Track: $dep" "$tracks_file"; then
            return 1 # Dependency not met
        fi
    fi
    return 0
}

update_tracks_from_blackboard() {
    local tracks_file="$1"
    local tmp_file=$(mktemp)
    
    while IFS= read -r line; do
        if [[ "$line" == "- [ ] **Track:"* ]]; then
            local track_name=$(echo "$line" | sed 's/^- \[ \] \*\*Track: //;s/\*\*.*//')
            local track_slug=$(echo "$track_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g;s/--\+/-/g;s/^-//;s/-$//')
            local status=$(blackboard_get "track_status_$track_slug")
            
            if [[ "$status" == "approved" ]]; then
                # Mark as complete in file
                echo "- [x] **Track: $track_name** (Done ✅)" >> "$tmp_file"
                # Perform git merge if needed
                merge_track_pr "$track_slug" "$track_name" || true
            elif [[ "$status" == "completed" ]]; then
                # Mark as pending review (Review Pattern)
                echo "- [ ] **Track: $track_name** (Review Required 🔍)" >> "$tmp_file"
                blackboard_set "track_status_$track_slug" "pr_ready"
                # Commit changes
                commit_track_changes "$track_slug" "$track_name" || true
            else
                echo "$line" >> "$tmp_file"
            fi
        else
            echo "$line" >> "$tmp_file"
        fi
    done < "$tracks_file"
    
    mv "$tmp_file" "$tracks_file"
}

spawn_workers() {
    local tracks_file="$1"
    log_info "Spawning workers if needed..."

    local max_workers=$(blackboard_get "conductor_max_workers")
    [[ -z "$max_workers" || "$max_workers" == "None" ]] && max_workers=1
    log_info "Max workers: $max_workers"

    # Build list of available agents (check which CLI tools are installed)
    local available_agents=""
    [[ -n "$(command -v gemini 2>/dev/null || command -v gemini-cli 2>/dev/null)" ]] && available_agents="gemini"
    [[ -n "$(command -v qwen-code 2>/dev/null || command -v qwen 2>/dev/null)" ]] && available_agents="${available_agents:+$available_agents,}qwen"
    [[ -n "$(command -v claude-code 2>/dev/null || command -v claude 2>/dev/null)" ]] && available_agents="${available_agents:+$available_agents,}claude"
    [[ -n "$(command -v deepseek-cli 2>/dev/null || command -v deepseek 2>/dev/null)" ]] && available_agents="${available_agents:+$available_agents,}deepseek"
    [[ -n "$(command -v nemo-cli.py 2>/dev/null || command -v nemoclaw 2>/dev/null)" ]] && available_agents="${available_agents:+$available_agents,}nemoclaw"
    [[ -n "$(command -v elc 2>/dev/null || command -v vllm 2>/dev/null)" ]] && available_agents="${available_agents:+$available_agents,}vllm"

    # Find all tracks marked as [ ]
    local open_tracks=$(grep -c "^\- \[ \] \*\*Track:" "$tracks_file" || true)
    log_info "Found $open_tracks open tracks."
    
    grep "^\- \[ \] \*\*Track:" "$tracks_file" | while read -r line; do
        log_info "Evaluating track: $line"
        # Stop if we already have max workers
        local current_workers=$(hcom list --name "$HCOM_NAME" --names | grep -c "worker_" || true)
        if [[ "$current_workers" -ge "$max_workers" ]]; then
            break
        fi

        # Check dependencies
        if ! check_track_dependencies "$line" "$tracks_file"; then
            continue
        fi

        local next_track=$(echo "$line" | sed 's/^- \[ \] \*\*Track: //;s/\*\*.*//')
        local track_slug=$(echo "$next_track" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g;s/--\+/-/g;s/^-//;s/-$//')

        local assigned_agent=$(blackboard_get "track_assigned_$track_slug")
        local track_status=$(blackboard_get "track_status_$track_slug")
        
        # --- Handle Review Assignment (Review Pattern) ---
        if [[ "$track_status" == "pr_ready" ]]; then
            local reviewer=$(blackboard_get "track_reviewer_$track_slug")
            local reviewer_alive=false
            if [[ -n "$reviewer" && "$reviewer" != "None" ]]; then
                if hcom list --names | grep -q "\b$reviewer\b"; then
                    reviewer_alive=true
                fi
            fi
            
            if [[ "$reviewer_alive" == false ]]; then
                log_info "Assigning reviewer for track: $next_track"
                
                # Select best reviewer (Gemini/Claude preferred for review)
                local selected_reviewer=$(agent_select_healthy_best "review this code changes for track $next_track" "$available_agents")
                
                # Spawn Reviewer
                local new_reviewer_name="reviewer_$(date +%s)_$RANDOM"
                hcom 1 "$selected_reviewer" --as "$new_reviewer_name" --tag reviewer --headless --go > /dev/null 2>&1 || true
                
                blackboard_set "track_reviewer_$track_slug" "$new_reviewer_name"
                local branch=$(blackboard_get "track_branch_$track_slug")
                
                local msg="Your task is to REVIEW the changes for track: $next_track.
                1. Checkout branch: $branch
                2. Review the diff and run tests.
                3. If good, send '!approve $track_slug'.
                4. If bad, provide feedback to the implementer."
                
                hcom send "@$new_reviewer_name" --name "$HCOM_NAME" --intent request --thread "code-review" -- "$msg"
                log_success "Assigned reviewer $new_reviewer_name ($selected_reviewer) to $track_slug"
            fi
            continue # Move to next track, implementer is done
        fi

        local agent_alive=false
        if [[ -n "$assigned_agent" ]]; then
            if hcom list --names | grep -q "\b$assigned_agent\b"; then
                agent_alive=true
            fi
        fi

        if [[ "$agent_alive" == false ]]; then
            log_info "Assigning new worker for track: $next_track"

            # 1. Create Git Branch for the track
            create_track_branch "$track_slug" || true
            local branch=$(blackboard_get "track_branch_$track_slug")

            # 2. Select best agent for this task using capability-based routing
            # Only consider healthy agents (respects circuit breaker)
            local selected_agent="gemini"  # Default fallback
            if [[ -n "$available_agents" ]]; then
                selected_agent=$(agent_select_healthy_best "$next_track" "$available_agents")
                # If selection returned empty, fall back to first healthy available
                if [[ -z "$selected_agent" ]]; then
                    # Find first healthy agent
                    IFS=',' read -ra avail_arr <<< "$available_agents"
                    for avail_agent in "${avail_arr[@]}"; do
                        if agent_is_healthy "$avail_agent" 2>/dev/null; then
                            selected_agent="$avail_agent"
                            break
                        fi
                    done
                fi
                # If still no healthy agent, skip this track
                if [[ -z "$selected_agent" ]]; then
                    log_warn "No healthy agents available for track: $next_track (skipping)"
                    continue
                fi
                log_info "Selected agent '$selected_agent' for track '$next_track' (healthy agents from: $available_agents)"
            fi

            # Get the CLI command for the selected agent
            local cli_cmd
            cli_cmd=$(python3 -c "
import json
config = json.load(open('$PROJECT_ROOT/config/agent-capabilities.json'))
agents = config.get('agents', {})
agent = agents.get('$selected_agent', {})
cli = agent.get('cli_command', 'gemini')
fallback = agent.get('fallback_cli_command', '')
import shutil
if shutil.which(cli):
    print(cli)
elif fallback and shutil.which(fallback):
    print(fallback)
else:
    print('gemini')
" 2>/dev/null)

            # 3. Spawn Agent
            local new_worker_name="worker_$(date +%s)_$RANDOM"
            local spawn_out
            
            local wrapper_args=("--as" "$new_worker_name" "--tag" "worker" "--headless" "--go")
            
            # Check for Container Mode (P4.1)
            local container_mode=$(blackboard_get "conductor_container_mode")
            if [[ "$container_mode" == "true" ]] && command -v docker >/dev/null 2>&1; then
                wrapper_args+=("--docker")
                log_info "Container mode enabled. Spawning $selected_agent in Docker..."
            fi

            spawn_out=$(hcom 1 "$cli_cmd" "${wrapper_args[@]}" 2>&1 || true)
            local new_agent=$(echo "$spawn_out" | grep "^Names: " | awk '{print $2}' || true)

            if [[ -n "$new_agent" ]]; then
                log_success "Spawned agent $new_agent ($selected_agent via $cli_cmd) for $track_slug (Branch: ${branch:-None})"
                blackboard_set "track_assigned_$track_slug" "$new_agent"
                blackboard_set "agent_task_$new_agent" "$next_track"

                # Register agent capabilities in blackboard
                agent_register_capabilities "$selected_agent" 2>/dev/null || true

                local msg="Your task is to implement the following track: $next_track. Please review conductor/tracks.md for specifications and report progress via the blackboard (hcom-kv)."
                [[ -n "$branch" ]] && msg="$msg Note: You should work in the git branch: $branch"

                hcom send "@$new_agent" --name "$HCOM_NAME" --intent request --thread "task-handoff" -- "$msg"
            fi
        fi
    done
    log_info "Finished spawning workers."
}

run_automated_tests() {
    log_info "Running automated test harness..."
    local test_out=$(bash "$SCRIPT_DIR/test-launch-options.sh" 2>&1 || echo "Tests failed")
    
    if echo "$test_out" | grep -q "Total Tests:.*Failed: 0"; then
        blackboard_set "test_last_status" "PASS"
        log_success "All tests passed."
    else
        blackboard_set "test_last_status" "FAIL"
        log_error "Some tests failed. Check logs."
    fi
}

# Helper to robustly extract fields from hcom events (handles raw table or flattened view)
extract_event_value() {
    local json="$1"
    local field="$2"
    local val=""

    # 1. Try fast sed extraction for top-level string fields: "field":"value"
    val=$(echo "$json" | sed -n 's/.*"'"$field"'": *"\([^"]*\)".*/\1/p' | head -n 1)

    # 2. Try numeric value (no quotes): "field":123
    if [[ -z "$val" ]]; then
        val=$(echo "$json" | sed -n 's/.*"'"$field"'": *\([^,}]*\).*/\1/p' | head -n 1)
    fi

    # 3. Try with msg_ prefix: "msg_field":"value"
    if [[ -z "$val" ]]; then
        val=$(echo "$json" | sed -n 's/.*"msg_'"$field"'": *"\([^"]*\)".*/\1/p' | head -n 1)
        if [[ -z "$val" ]]; then
            val=$(echo "$json" | sed -n 's/.*"msg_'"$field"'": *\([^,}]*\).*/\1/p' | head -n 1)
        fi
    fi

    # 4. Fallback to python for nested data or complex cases
    if [[ -z "$val" ]]; then
        val=$(python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    if sys.argv[2] in d:
        print(d[sys.argv[2]])
    elif 'data' in d and isinstance(d['data'], dict):
        print(d['data'].get(sys.argv[2], ''))
    elif 'data' in d and isinstance(d['data'], str):
        data = json.loads(d['data'])
        print(data.get(sys.argv[2], ''))
    else:
        print('')
except Exception:
    print('')
" "$json" "$field" 2>/dev/null)
    fi
    echo "$val"
}

process_protocol_message() {
    log_info "Entering process_protocol_message..."
    local event_json="$1"
    # Protocol extraction logic (P6.3)
    # Check for structured 'intent' and 'type' fields
    local intent=$(extract_event_value "$event_json" "intent")
    log_info "process_protocol_message: intent=$intent"
    if [[ "$intent" == "status" || "$intent" == "inform" ]]; then
        # This is a protocol-aligned message, handle accordingly
        return 0
    fi
    # Always return 0 to avoid exiting due to set -e
    return 0
}

process_commands() {
    log_info "Entering process_commands..."
    local event_json="$1"
    local type=$(extract_event_value "$event_json" "type")
    log_info "process_commands: type=$type"

    # Type might be empty since we already filter by --type message in hcom events
    if [[ "$type" != "message" && -n "$type" ]]; then
        log_info "process_commands: skipping non-message type: $type"
        return 0
    fi

    local from=$(extract_event_value "$event_json" "from")
    local text=$(extract_event_value "$event_json" "text")
    local thread=$(extract_event_value "$event_json" "thread")
    log_info "process_commands: from='$from' text='$text' thread='$thread'"

    # We only care about command triggers starting with !
    if [[ "$text" == !* ]]; then
        local cmd=$(echo "$text" | awk '{print $1}')
        log_info "Received command: $cmd from $from"

        case "$cmd" in
            "!smoke")
                log_info "Executing SMOKE TEST command..."
                # Execute hello_world.sh and redirect output to smoke_output.txt
                bash "$PROJECT_ROOT/hello_world.sh" > "$PROJECT_ROOT/smoke_output.txt" 2>&1 || echo "Smoke test failed" > "$PROJECT_ROOT/smoke_output.txt"
                ;;
            "!test")
                    hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Initiating full test suite..."
                    run_automated_tests
                    ;;
                "!approve")
                    local target=$(echo "$text" | awk '{print $2}')
                    if [[ -n "$target" ]]; then
                        # Try to find a track that matches the slug or name
                        local track_found=false
                        grep "^\- \[ \] \*\*Track:" "$TRACKS_FILE" | while read -r line; do
                            local track_name=$(echo "$line" | sed 's/^- \[ \] \*\*Track: //;s/\*\*.*//')
                            local track_slug=$(echo "$track_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g;s/--\+/-/g;s/^-//;s/-$//')

                            if [[ "$target" == "$track_slug" || "$target" == "$track_name" ]]; then
                                hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Approving track: $track_name..."
                                blackboard_set "track_status_$track_slug" "approved"
                                # We don't merge here, it will be picked up by the next loop iteration
                                track_found=true
                                break
                            fi
                        done
                    else
                        hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Usage: !approve <track_slug_or_name>"
                    fi
                    ;;
                "!smoke")
                    hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Running system smoke test..."
                    if [[ -f "$PROJECT_ROOT/hello_world.sh" ]]; then
                        local output=$(bash "$PROJECT_ROOT/hello_world.sh" 2>&1)
                        hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Smoke Test Output: $output"
                        blackboard_set "smoke_test_last_run" "$(date +%s)"
                        blackboard_set "smoke_test_last_output" "$output"
                        # Write to file for physical verification
                        echo "$output" > "$PROJECT_ROOT/smoke_output.txt"
                    else
                        hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Error: hello_world.sh not found in $PROJECT_ROOT"
                    fi
                    ;;
                "!status")
                    local progress=$(blackboard_get "project_progress")
                    local active=$(blackboard_get "active_track")
                    local test_status=$(blackboard_get "test_last_status")
                    
                    # Build status message with module-specific info
                    local msg="Project Health: Progress ${progress:-N/A} | Active Track: ${active:-None} | Tests: ${test_status:-N/A}"
                    
                    # Add module-specific status (dynamically)
                    if [[ -f "$SCRIPT_DIR/module-manager.sh" ]]; then
                        # Check for any active modules and add their status
                        local active_modules=$(bash "$SCRIPT_DIR/module-manager.sh" active 2>/dev/null | grep -v "^Available\|^Active\|^$" | wc -l)
                        if [[ "$active_modules" -gt 0 ]]; then
                            msg="$msg | Modules: $active_modules active"
                        fi
                    fi
                    
                    hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "$msg"
                    ;;
                "!switch")
                    local new_path=$(echo "$text" | awk '{print $2}')
                    if [[ -d "$new_path" ]]; then
                        hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Switching project root to: $new_path"
                        # Update variables (this will affect the next iteration)
                        PROJECT_ROOT="$new_path"
                        TRACKS_FILE="$PROJECT_ROOT/conductor/tracks.md"
                        blackboard_set "conductor_current_project" "$PROJECT_ROOT"
                        # Re-evaluate all tracks next iteration
                        sync_blackboard_status "$TRACKS_FILE"
                    else
                        hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Error: Directory not found: $new_path"
                    fi
                    ;;
                "!build")
                    hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Starting project build..."
                    if make build > /dev/null 2>&1; then
                        hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Build successful."
                    else
                        hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Build failed."
                    fi
                    ;;
                "!git-sync")
                    hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Syncing with remote repository..."
                    local sync_out=$(git pull 2>&1 || echo "Git pull failed")
                    hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Sync result: $sync_out"
                    ;;
                "!kb")
                    local query=$(echo "$text" | cut -d' ' -f2-)
                    local map_file="$PROJECT_ROOT/conductor/knowledge_base_map.md"

                    if [[ ! -f "$map_file" ]]; then
                        hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Error: Knowledge base map not found. Running indexer..."
                        bash "$SCRIPT_DIR/hcom-kb-index.sh" > /dev/null 2>&1 || true
                    fi

                    hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Searching Semantic Knowledge Base for: $query"

                    # 1. Identify relevant files using the map
                    local search_prompt="Based on the following Project Map, identify the top 3 most relevant file paths for the query: '$query'. Return ONLY a comma-separated list of paths relative to the project root.
                    Map:
                    $(cat "$map_file")"

                    local file_list=$(gemini --model gemini-3.0 --headless --prompt "$search_prompt" 2>&1 | tr -d '\n' | sed 's/ //g')
                    log_info "Identified files: $file_list"

                    # 2. Retrieve content and generate final answer
                    local combined_content=""
                    IFS=',' read -ra ADDR <<< "$file_list"
                    for file in "${ADDR[@]}"; do
                        if [[ -f "$PROJECT_ROOT/$file" ]]; then
                            combined_content="$combined_content
                            --- FILE: $file ---
                            $(cat "$PROJECT_ROOT/$file")"
                        fi
                    done

                    if [[ -n "$combined_content" ]]; then
                        local final_prompt="Based on the following project context and documentation, provide a comprehensive architectural answer to the query: '$query'.
                        Context:
                        $combined_content"

                        local answer=$(gemini --model gemini-3.0 --headless --prompt "$final_prompt" 2>&1)
                        hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "$answer"
                    else
                        hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "No relevant architectural guidance found for '$query'."
                    fi
                    ;;
                "!kb-refresh")
                    hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Refreshing Semantic Knowledge Base Index..."
                    bash "$SCRIPT_DIR/hcom-kb-index.sh" > /dev/null 2>&1 || true
                    hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Index refreshed."
                    ;;
                "!web-start")
                    hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Starting Visual Health Dashboard on http://localhost:5050..."
                    python3 "$SCRIPT_DIR/hom-web-dashboard.py" > /tmp/hcom-web.log 2>&1 &
                    echo $! > /tmp/hcom-web.pid
                    ;;
                "!web-stop")
                    if [ -f /tmp/hcom-web.pid ]; then
                        kill $(cat /tmp/hcom-web.pid) && rm /tmp/hcom-web.pid
                        hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Web dashboard stopped."
                    fi
                    ;;
                "!help")
                    # Build help message with core and module commands
                    local core_cmds="!status, !test, !approve, !build, !git-sync, !kb <query>, !kb-refresh, !web-start, !web-stop, !evolve, !switch <path>"
                    
                    # Add module commands dynamically
                    local mod_cmds=""
                    if [[ -f "$SCRIPT_DIR/module-manager.sh" ]]; then
                        mod_cmds=$(bash "$SCRIPT_DIR/module-manager.sh" commands all 2>/dev/null | grep -v "^Conductor\|^$" | cut -d'→' -f1 | tr '\n' ', ' | sed 's/, $//')
                    fi
                    
                    local help_msg="Core Commands: $core_cmds"
                    [[ -n "$mod_cmds" ]] && help_msg="$help_msg | Module Commands: $mod_cmds"
                    help_msg="$help_msg | !help"
                    
                    hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "$help_msg"
                    ;;
                "!evolve")
                    hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Analyzing project for autonomous evolution..."

                    # Gather context
                    local product_ctx=$(cat "$PROJECT_ROOT/conductor/product.md" | sed -n '/## Future Considerations/,$p')
                    local tracks_ctx=$(cat "$TRACKS_FILE" | grep "^\- \[" | head -n 20)
                    local map_ctx=""
                    [ -f "$PROJECT_ROOT/conductor/knowledge_base_map.md" ] && map_ctx=$(cat "$PROJECT_ROOT/conductor/knowledge_base_map.md" | head -n 50)

                    local evolve_prompt="You are the Hub Conductor. Analyze the following project goals and current track status. Suggest the NEXT 3 tracks to implement to move the project forward. Return as a markdown list.
                    Project Goals:
                    $product_ctx
                    Current Tracks:
                    $tracks_ctx
                    Project Map:
                    $map_ctx"

                    local suggestions=$(gemini --model gemini-3.0 --headless --prompt "$evolve_prompt" 2>&1)
                    hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Autonomous Evolution Suggestions:
                    $suggestions"
                    ;;
            esac
        fi
}

update_tmux_status_bar() {
    local current_time="$1"
    log_info "Updating status bar for time $current_time..."
    # Aggregate health metrics
    local health_data=$(blackboard_list "fleet_health_")
    local status_str=""
    
    while IFS='|' read -r key health_json; do
        [[ -z "$key" || -z "$health_json" ]] && continue
        local agent_name=${key#fleet_health_}
        log_info "Processing health for $agent_name..."
        local status=$(extract_json_value "$health_json" "status")
        local last_ts=$(extract_json_value "$health_json" "ts")
        
        # Truncate/Shorten name using shell slicing
        local short_name=$(echo "${agent_name:0:3}" | tr '[:lower:]' '[:upper:]')
        
        local icon="✓"
        [[ "$status" == "busy" || "$status" == "coding" ]] && icon="⏳"
        
        # Check for staleness
        if (( current_time - last_ts > 60 )); then
            icon="✗"
        fi
        
        status_str="$status_str [$icon $short_name]"
    done <<< "$health_data"
    
    if [[ -n "$status_str" ]]; then
        tmux set-option -g status-right "$status_str" > /dev/null 2>&1 || true
    fi
}

main() {
    # ============================================================
    # State Recovery (P25.3)
    # ============================================================
    log_info "Recovering conductor state..."

    # Recover event cursor from blackboard
    local saved_cursor
    saved_cursor=$(blackboard_get "conductor_event_cursor" 2>/dev/null || echo "")
    if [[ -n "$saved_cursor" ]]; then
        LAST_EVENT_ID="$saved_cursor"
        log_info "Recovered event cursor: $LAST_EVENT_ID"
    fi

    # Recover active track from blackboard
    local saved_track
    saved_track=$(blackboard_get "active_track" 2>/dev/null || echo "")
    if [[ -n "$saved_track" ]]; then
        log_info "Recovered active track: $saved_track"
    fi

    # Validate blackboard state
    log_info "Validating blackboard state..."
    local progress
    progress=$(blackboard_get "project_progress" 2>/dev/null || echo "0%")
    log_info "Project progress: $progress"

    # Save conductor PID for watchdog
    echo $$ > "/tmp/ai-colab-conductor.pid"

    ITERATION=0
    log_info "Starting main loop..."
    while true; do
        ITERATION=$((ITERATION+1))
        # Cache current time for the whole iteration
        CURRENT_TIME=$(date +%s)
        log_info "Iteration $ITERATION start - Time: $CURRENT_TIME"

        # Render high-density dashboard (Skip in CI)
        if [[ "${CI:-}" != "true" ]]; then
            log_info "Rendering dashboard..."
            bash "$SCRIPT_DIR/conductor-dashboard.sh"
        fi

        # Update tmux status bar with fleet health
        log_info "Updating status bar..."
        update_tmux_status_bar "$CURRENT_TIME"
        log_info "Status bar updated."

        # ============================================================
        # 1. Event Polling (High Priority)
        # ============================================================
        # Fetch events since last cursor position (using --name to ensure identity)
        local events_processed=0
        local TMP_CURSOR_FILE=$(mktemp)
        echo "$LAST_EVENT_ID" > "$TMP_CURSOR_FILE"
        
        log_info "Polling for new events since ID: $LAST_EVENT_ID..."
        local TMP_EVENTS=$(mktemp)
        hcom events --name "$HCOM_NAME" --all --type message --sql "id >= $LAST_EVENT_ID" --last 10 > "$TMP_EVENTS" || true
        
        while read -r line; do
            # Skip update notifications or empty lines
            if [[ ! "$line" == \{* ]]; then
                continue
            fi
            
            local event_id=$(extract_event_value "$line" "id")
            if [[ -n "$event_id" ]]; then
                log_info "Working on event ID: $event_id"
            else
                log_warn "Failed to extract event ID from line: ${line:0:100}..."
            fi
            if [[ -n "$event_id" ]]; then
                # Check for deduplication
                local already_processed=$(conductor_is_event_processed "$event_id")
                local current_cursor=$(cat "$TMP_CURSOR_FILE")
                log_info "Event $event_id: already_processed=$already_processed, current_cursor=$current_cursor"
                
                if [[ "$already_processed" != "true" && "$event_id" -gt "$current_cursor" ]]; then
                    log_info "Processing event $event_id..."

                    # First, try to process as structured protocol message (P6.3)
                    process_protocol_message "$line"
                    log_info "Finished process_protocol_message for $event_id."
                    
                    # Then, process as command if it starts with !
                    process_commands "$line"
                    log_info "Finished process_commands for $event_id."
                    
                    # Mark as processed
                    conductor_mark_event_processed "$event_id"
                    # Update cursor in temp file
                    echo "$event_id" > "$TMP_CURSOR_FILE"
                    # Update cursor in blackboard (for recovery)
                    conductor_set_event_cursor "$event_id"
                    ((events_processed++)) || true
                fi
            fi
        done < "$TMP_EVENTS"
        rm -f "$TMP_EVENTS"

        log_info "Polling complete for this iteration."

        # Update local cursor from temp file
        LAST_EVENT_ID=$(cat "$TMP_CURSOR_FILE")
        rm -f "$TMP_CURSOR_FILE"

        # ============================================================
        # 2. Conductor Heartbeat & State Persistence
        # ============================================================
        # Write heartbeat to blackboard every 30 seconds
        if (( CURRENT_TIME % 30 < INTERVAL )); then
            local heartbeat_data="{\"ts\":$CURRENT_TIME,\"status\":\"running\",\"pid\":$$,\"uptime\":$((CURRENT_TIME - CONDUCTOR_START_TS))}"
            blackboard_set "conductor_heartbeat" "$heartbeat_data" 2>/dev/null || true
            log_info "Conductor heartbeat written"
        fi

        # Save event cursor to blackboard for recovery (P25.3)
        if [[ -n "${LAST_EVENT_ID:-}" ]]; then
            blackboard_set "conductor_event_cursor" "$LAST_EVENT_ID" 2>/dev/null || true
        fi

        # ============================================================
        # 3. Project & Task Orchestration
        # ============================================================
        log_info "Syncing project status..."
        sync_blackboard_status "$TRACKS_FILE"

        log_info "Checking for task assignments..."
        spawn_workers "$TRACKS_FILE"

        log_info "Checking for periodic tests..."
        if (( CURRENT_TIME - LAST_TEST_RUN > TEST_INTERVAL )); then
            log_info "Running scheduled tests..."
            run_automated_tests
            LAST_TEST_RUN=$CURRENT_TIME
        fi

        # ============================================================
        # 4. Fleet Watchdog & Autonomous Recovery
        # ============================================================
        log_info "Running Fleet Watchdog..."
        local all_health
        all_health=$(blackboard_list "fleet_health_")
        
        while IFS='|' read -r key health_json; do
            [[ -z "$key" || -z "$health_json" ]] && continue
            
            local agent_name=${key#fleet_health_}
            local last_ts=$(extract_json_value "$health_json" "ts")
            local status=$(extract_json_value "$health_json" "status")
            
            # Check for stale heartbeat (> 60 seconds)
            if [[ "$status" != "stale" ]] && (( CURRENT_TIME - last_ts > 60 )); then
                log_warn "Agent STALE: $agent_name (last seen: $((CURRENT_TIME - last_ts))s ago)"
                
                # Attempt Recovery
                hcom send --name "$HCOM_NAME" -- "Watchdog: Agent $agent_name is unresponsive. Attempting recovery..." > /dev/null 2>&1 || true
                blackboard_set "recovery_attempt_${agent_name}" "$CURRENT_TIME"
                
                # Update status to 'stale' in blackboard
                local updated_json="{\"status\":\"stale\",\"latency\":0,\"load\":0,\"ts\":$last_ts}"
                blackboard_set "$key" "$updated_json"
                
                # Critical failover logic
                if [[ "$agent_name" == nemoclaw* ]]; then
                    log_info "Critical Spoke Failed: nemoclaw. Diverting architectural tasks to Claude."
                    blackboard_set "failover_architect" "claude"
                fi
            fi
        done <<< "$all_health"

        # Check for periodic module hooks
        if [[ -f "$SCRIPT_DIR/module-manager.sh" ]]; then
            # Get list of all active modules
            while IFS= read -r module_id; do
                if [[ -n "$module_id" ]]; then
                    # Parse periodic hooks for this module: name|script|interval
                    while IFS='|' read -r hook_name script interval; do
                        if [[ -n "$hook_name" && -n "$script" ]]; then
                            local bb_key="hook_last_run_${module_id}_${hook_name}"
                            local last_run=$(blackboard_get "$bb_key" || echo 0)
                            
                            if (( CURRENT_TIME - last_run > interval )); then
                                log_info "Executing periodic hook: $hook_name ($module_id)..."
                                # Execute using module manager to handle venv
                                bash "$SCRIPT_DIR/module-manager.sh" run "$module_id" "$script" > /dev/null 2>&1 || true
                                blackboard_set "$bb_key" "$CURRENT_TIME"
                            fi
                        fi
                    done < <(bash "$SCRIPT_DIR/module-manager.sh" periodic "$module_id" 2>/dev/null)
                fi
            done < <(bash "$SCRIPT_DIR/module-manager.sh" active 2>/dev/null)
        fi

        # Check for periodic KB indexing (once every 12 hours)
        if [[ ! -f "$PROJECT_ROOT/conductor/knowledge_base_map.md" ]] || (( CURRENT_TIME - $(blackboard_get "kb_last_indexed_ts" || echo 0) > 43200 )); then
            log_info "Running scheduled KB indexing..."
            bash "$SCRIPT_DIR/hcom-kb-index.sh" > /dev/null 2>&1 || true
            blackboard_set "kb_last_indexed_ts" "$CURRENT_TIME"
        fi

        # Wait for next interval
        log_info "Sleeping for $INTERVAL seconds..."
        sleep "$INTERVAL"

    done
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
