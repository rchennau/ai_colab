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

# 1. Project Detection
PROJECT_ROOT=$(detect_project_root 2>/dev/null || dirname "$SCRIPT_DIR")
TRACKS_FILE="$PROJECT_ROOT/conductor/tracks.md"
INTERVAL=${CONDUCTOR_INTERVAL:-60} # Default to 60 seconds
TEST_INTERVAL=900 # 15 minutes
SCREENSHOT_INTERVAL=300 # 5 minutes
LAST_TEST_RUN=0
LAST_SCREENSHOT_TIME=0
# Tracking variables for status broadcasts to avoid noise
LAST_BROADCAST_PCT=""
LAST_BROADCAST_TRACK=""
LAST_BROADCAST_TIME=0
# Initialize last event ID to avoid processing old messages
LAST_EVENT_ID=$(hcom events --last 1 | grep -oP '"id":\K\d+' || echo "0")

# Agent registration
export HCOM_NAME="conductor_$(hostname | tr "[:upper:]" "[:lower:]" | tr "." "_")_$$"
register_hcom "conductor" || true
start_heartbeat "conductor" || true

cleanup() {
    if [ -n "${HEARTBEAT_PID:-}" ]; then
        kill "$HEARTBEAT_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Thread subscription
hcom events sub --agent "$HCOM_NAME" --thread "plan-sync" --once > /dev/null 2>&1 &
hcom events sub --agent "$HCOM_NAME" --thread "track-updates" > /dev/null 2>&1 &

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
    
    if [[ -n "$branch" ]]; then
        log_info "Merging branch $branch into current branch..."
        if git merge "$branch" -m "Auto-merge: Completed track $track_name" > /dev/null 2>&1; then
            log_success "Merge successful."
        else
            log_error "Merge conflict detected for track: $track_name. Manual resolution required."
            return 1
        fi
    fi
    
    # Update tracks.md status to [x]
    log_info "Updating tracks.md for $track_name..."
    local replacement="- [x] **Track: $track_name**"
    [[ -n "$commit_sha" ]] && replacement="$replacement ($commit_sha)"
    
    # Escape track name for sed
    local escaped_track_name=$(echo "$track_name" | sed 's/[^^]/[&]/g; s/\^/\\^/g')
    sed -i.bak "s/^- \[ \] \*\*Track: $escaped_track_name\*\*/$replacement/" "$TRACKS_FILE"
    rm -f "${TRACKS_FILE}.bak"
    
    # Clear blackboard status
    blackboard_set "track_status_$track_slug" "synced"
    blackboard_set "pr_$track_slug" "merged"
    blackboard_set "last_merged_track" "$track_name"
    
    return 0
}

update_tracks_from_blackboard() {
    local tracks_file="$1"
    
    # List all tracks in the file
    grep "^\- \[ \] \*\*Track:" "$tracks_file" | while read -r line; do
        local track_name=$(echo "$line" | sed 's/^- \[ \] \*\*Track: //;s/\*\*.*//')
        local track_slug=$(echo "$track_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g;s/--\+/-/g;s/^-//;s/-$//')
        
        # Check blackboard for status
        local status=$(blackboard_get "track_status_$track_slug")
        
        if [[ "$status" == "approved" ]]; then
            log_info "PR Approved for track: $track_name. Finalizing..."
            merge_track_pr "$track_slug" "$track_name"
            hcom send @all --intent inform --thread "plan-sync" -- "PR MERGED: $track_name. Changes integrated into project root."
            continue
        fi
        
        if [[ "$status" == "complete" ]]; then
            log_info "Track reported complete: $track_name. Validating..."
            
            # 1. Run Automated Tests before committing
            if bash "$SCRIPT_DIR/hcom-test-runner.sh" > /dev/null 2>&1; then
                log_success "Validation passed for $track_name."
                
                # 2. Commit changes to branch
                commit_track_changes "$track_slug" "$track_name" || true
                
                # 3. Create Pseudo-PR
                local commit_sha=$(blackboard_get "track_commit_$track_slug")
                local branch=$(blackboard_get "track_branch_$track_slug")
                
                blackboard_set "track_status_$track_slug" "pr_ready"
                blackboard_set "pr_$track_slug" "pending_approval"
                
                # Broadcast the PR
                hcom send @all --intent inform --thread "plan-sync" -- "PULL REQUEST READY: $track_name. Branch: ${branch:-main}. Commit: ${commit_sha:-no-commit}. Use '!approve $track_slug' to merge."
            else
                log_error "Validation FAILED for $track_name. Commit aborted."
                hcom send @all --intent inform --thread "plan-sync" -- "Validation FAILED for track: $track_name. Manual intervention required."
                blackboard_set "track_status_$track_slug" "failed_validation"
            fi
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
            hcom send @all --intent inform --thread "plan-sync" -- "Status: $complete/$total tracks complete ($percent%). Next up: ${next_track:-All complete}."
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
    # Using sed instead of grep -P for macOS/BSD compatibility
    local dep_name=$(echo "$track_line" | sed -n 's/.*(Requires: \(.*\)).*/\1/p' || echo "")
    
    if [[ -n "$dep_name" ]]; then
        # Check if the required track is marked as [x]
        if grep -q "\- \[x\] \*\*Track: $dep_name\*\*" "$tracks_file"; then
            return 0 # Met
        else
            return 1 # Not met
        fi
    fi
    return 0 # No dependency
}

create_track_branch() {
    local track_slug="$1"
    local branch_name="track/$track_slug"
    
    # Check if we are in a git repo
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        return 0
    fi
    
    # Check if branch already exists
    if git rev-parse --verify "$branch_name" > /dev/null 2>&1; then
        log_info "Git branch already exists: $branch_name"
        return 0
    fi
    
    log_info "Creating new git branch: $branch_name"
    if git checkout -b "$branch_name" > /dev/null 2>&1; then
        log_success "Switched to branch: $branch_name"
        # Store the branch in the blackboard
        blackboard_set "track_branch_$track_slug" "$branch_name"
        # Switch back to the previous branch (usually main) to allow conductor to continue
        git checkout - > /dev/null 2>&1
        return 0
    else
        log_error "Failed to create git branch: $branch_name"
        return 1
    fi
}

spawn_workers() {
    local tracks_file="$1"
    
    local max_workers=$(blackboard_get "conductor_max_workers")
    [[ -z "$max_workers" || "$max_workers" == "None" ]] && max_workers=1
    
    # Find all tracks marked as [ ]
    grep "^\- \[ \] \*\*Track:" "$tracks_file" | while read -r line; do
        # Stop if we already have max workers
        local current_workers=$(hcom list --names | grep -c "worker_" || true) # Check for our worker prefix
        if [[ "$current_workers" -ge "$max_workers" ]]; then
            # echo "[$(date +%T)] Max workers ($max_workers) reached. Skipping further spawns."
            break
        fi

        # Check dependencies
        if ! check_track_dependencies "$line" "$tracks_file"; then
            # echo "[$(date +%T)] Skipping track due to unmet dependency: $line"
            continue
        fi

        local next_track=$(echo "$line" | sed 's/^- \[ \] \*\*Track: //;s/\*\*.*//')
        local track_slug=$(echo "$next_track" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g;s/--\+/-/g;s/^-//;s/-$//')
        
        local assigned_agent=$(blackboard_get "track_assigned_$track_slug")
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

            # 2. Spawn Agent
            local new_worker_name="worker_$(date +%s)_$RANDOM"
            local spawn_out=$(hcom 1 gemini --as "$new_worker_name" --tag worker --headless --go 2>&1 || true)
            local new_agent=$(echo "$spawn_out" | grep "^Names: " | awk '{print $2}' || true)

            if [[ -n "$new_agent" ]]; then
                log_success "Spawned agent $new_agent for $track_slug (Branch: ${branch:-None})"
                blackboard_set "track_assigned_$track_slug" "$new_agent"
                blackboard_set "agent_task_$new_agent" "$next_track"
                
                local msg="Your task is to implement the following track: $next_track. Please review conductor/tracks.md for specifications and report progress via the blackboard (hcom-kv)."
                [[ -n "$branch" ]] && msg="$msg Note: You should work in the git branch: $branch"
                
                hcom send "@$new_agent" --name "$HCOM_NAME" --intent request --thread "task-handoff" -- "$msg"
            fi
        fi
    done
}

run_automated_tests() {
    log_info "Triggering automated test run..."
    bash "$SCRIPT_DIR/hcom-test-runner.sh" > /dev/null 2>&1 || true
    LAST_TEST_RUN=$(date +%s)
}

process_commands() {
    local event_json="$1"
    local type=$(extract_json_value "$event_json" "type")
    
    if [[ "$type" == "message" ]]; then
        local from=$(extract_json_value "$event_json" "msg_from")
        local text=$(extract_json_value "$event_json" "msg_text")
        local thread=$(extract_json_value "$event_json" "msg_thread")
        
        # We only care about command triggers starting with !
        if [[ "$text" == !* ]]; then
            local cmd=$(echo "$text" | awk '{print $1}')
            log_info "Received command: $cmd from $from"
            
            case "$cmd" in
                "!test")
                    hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Initiating full test suite..."
                    run_automated_tests
                    ;;
                "!screenshot")
                    hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Capturing emulator state..."
                    bash "$SCRIPT_DIR/hcom-atari-screen.sh" > /dev/null 2>&1 || true
                    LAST_SCREENSHOT_TIME=$CURRENT_TIME # Reset timer
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
                "!status")
                    local progress=$(blackboard_get "project_progress")
                    local active=$(blackboard_get "active_track")
                    local test_status=$(blackboard_get "test_last_status")
                    local build_time=$(blackboard_get "atari_last_build")
                    
                    hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- \
                        "Project Health: Progress ${progress:-N/A} | Active Track: ${active:-None} | Tests: ${test_status:-N/A} | Last Build: ${build_time:-N/A}"
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
                        bash "$SCRIPT_DIR/hcom-atari-sync.sh" > /dev/null 2>&1 || true
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
                "!profile")
                    local file=$(echo "$text" | awk '{print $2}')
                    if [[ -f "$file" ]]; then
                        hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Profiling performance for: $file"
                        bash "$SCRIPT_DIR/hcom-profiler.sh" "$file" > /dev/null 2>&1 || true
                    else
                        hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Error: File not found: $file"
                    fi
                    ;;
                "!help")
                    hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- \
                        "Conductor Commands: !status, !test, !screenshot, !build, !git-sync, !kb <query>, !profile <file>, !switch <path>, !help"
                    ;;
                *)
                    # Unknown command
                    ;;
            esac
        fi
    fi
}

main() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       Atari-LX Conductor Agent        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo -e "Agent: ${GREEN}$HCOM_NAME${NC}"
    echo -e "Monitoring: ${YELLOW}$TRACKS_FILE${NC}"
    echo -e "Interval: ${INTERVAL}s"
    echo ""

    while true; do
        echo -e "[$(date +%T)] ${BLUE}Syncing project status...${NC}"
        sync_blackboard_status "$TRACKS_FILE"
        
        echo -e "[$(date +%T)] ${BLUE}Checking for task assignments...${NC}"
        spawn_workers "$TRACKS_FILE"
        
        # Check for periodic tests
        CURRENT_TIME=$(date +%s)
        if (( CURRENT_TIME - LAST_TEST_RUN > TEST_INTERVAL )); then
            echo -e "[$(date +%T)] ${YELLOW}Running scheduled tests...${NC}"
            run_automated_tests
        fi

        # Check for periodic screenshots
        if (( CURRENT_TIME - LAST_SCREENSHOT_TIME > SCREENSHOT_INTERVAL )); then
            log_info "Capturing scheduled screenshot..."
            bash "$SCRIPT_DIR/hcom-atari-screen.sh" > /dev/null 2>&1 || true
            LAST_SCREENSHOT_TIME=$CURRENT_TIME
        fi

        # Check for periodic KB indexing (once every 12 hours)
        if [[ ! -f "$PROJECT_ROOT/conductor/knowledge_base_map.md" ]] || (( CURRENT_TIME - $(blackboard_get "kb_last_indexed_ts" || echo 0) > 43200 )); then
            log_info "Running scheduled KB indexing..."
            bash "$SCRIPT_DIR/hcom-kb-index.sh" > /dev/null 2>&1 || true
            blackboard_set "kb_last_indexed_ts" "$CURRENT_TIME"
        fi

        # Process new hcom events (commands)        local TMP_ID_FILE="/tmp/conductor_last_event_id_$$"
        echo "$LAST_EVENT_ID" > "$TMP_ID_FILE"
        
        # hcom events --all returns one JSON object per line for multiple events
        # We want to be quiet here unless we actually process something
        hcom events --all --sql "id > $LAST_EVENT_ID AND type='message'" --last 5 | while read -r line; do
            if [[ -n "$line" && "$line" == \{* ]]; then
                local event_id=$(extract_json_value "$line" "id")
                if [[ -n "$event_id" && "$event_id" -gt "$(cat "$TMP_ID_FILE")" ]]; then
                    echo -e "[$(date +%T)] ${GREEN}Processing event $event_id...${NC}"
                    process_commands "$line"
                    echo "$event_id" > "$TMP_ID_FILE"
                fi
            fi
        done
        LAST_EVENT_ID=$(cat "$TMP_ID_FILE")
        rm -f "$TMP_ID_FILE"

        # Wait for next interval or interrupt
        echo -n -e "[$(date +%T)] ${BLUE}Listening for events...${NC}\r"
        hcom listen --timeout "$INTERVAL" --name "$HCOM_NAME" > /dev/null 2>&1 || sleep "$INTERVAL"
        echo -e "\033[K" # Clear the line
    done
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
