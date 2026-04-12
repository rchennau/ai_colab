#!/usr/bin/env bash
# Real-Time Fleet Status Bar Updater (P17.4)
# Continuously updates tmux status line with per-agent health status
# Updates every 20 seconds via heartbeat data from blackboard
#
# Usage: bash update-status-bar.sh [session_name]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Configuration
UPDATE_INTERVAL=20  # seconds
SESSION="${1:-hcom-dashboard}"

# Agent list to monitor
AGENTS=("gemini" "qwen" "claude" "deepseek")

# Colors for tmux status line
# tmux uses #[] for color formatting
COLOR_READY="#[fg=green]✓"
COLOR_BUSY="#[fg=yellow]⏳"
COLOR_CRASHED="#[fg=red]✗"
COLOR_UNKNOWN="#[fg=colour245]?"
COLOR_RESET="#[default]"

# Generate status bar content
generate_status() {
    local status=""

    for agent in "${AGENTS[@]}"; do
        local health
        health=$(blackboard_get "fleet_health_$agent" 2>/dev/null || echo "")

        if [[ -z "$health" ]]; then
            status+="${COLOR_UNKNOWN} ${agent}${COLOR_RESET} "
        elif echo "$health" | grep -q '"status":"ready"'; then
            status+="${COLOR_READY} ${agent}${COLOR_RESET} "
        elif echo "$health" | grep -q '"status":"busy"'; then
            status+="${COLOR_BUSY} ${agent}${COLOR_RESET} "
        elif echo "$health" | grep -q '"status":"crashed"'; then
            status+="${COLOR_CRASHED} ${agent}${COLOR_RESET} "
        elif echo "$health" | grep -q '"status":"unhealthy"'; then
            status+="${COLOR_CRASHED} ${agent}${COLOR_RESET} "
        else
            status+="${COLOR_UNKNOWN} ${agent}${COLOR_RESET} "
        fi
    done

    echo "$status"
}

# Update tmux status line
update_status_line() {
    local status
    status=$(generate_status)

    # Update tmux status-left with fleet status
    tmux set-option -g status-left "$status" 2>/dev/null || true
}

# Main loop
main() {
    echo "Starting fleet status bar updater for session: $SESSION"
    echo "Update interval: ${UPDATE_INTERVAL}s"
    echo "Monitoring agents: ${AGENTS[*]}"
    echo ""

    # Initial update
    update_status_line

    # Continuous updates
    while true; do
        sleep "$UPDATE_INTERVAL"
        update_status_line
    done
}

main "$@"
