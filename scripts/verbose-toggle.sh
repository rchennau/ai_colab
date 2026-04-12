#!/usr/bin/env bash
# ai-colab Verbose Toggle Handler (P6.4)
# Manages compact/verbose display mode for the dashboard.
#
# In compact mode: shows structured summaries from protocol messages
# In verbose mode: shows full agent CLI output
#
# Usage:
#   bash verbose-toggle.sh toggle           # Toggle mode
#   bash verbose-toggle.sh status           # Show current mode
#   bash verbose-toggle.sh set compact      # Set to compact mode
#   bash verbose-toggle.sh set verbose      # Set to verbose mode

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Blackboard key for verbose mode state
VERBOSE_MODE_KEY="dashboard_verbose_mode"

# Get current verbose mode
get_verbose_mode() {
    local mode
    mode=$(blackboard_get "$VERBOSE_MODE_KEY" 2>/dev/null || echo "compact")
    echo "${mode:-compact}"
}

# Set verbose mode
set_verbose_mode() {
    local mode="$1"
    if [[ "$mode" != "compact" && "$mode" != "verbose" ]]; then
        echo "Error: Mode must be 'compact' or 'verbose'" >&2
        return 1
    fi
    blackboard_set "$VERBOSE_MODE_KEY" "$mode" 2>/dev/null || true
}

# Toggle verbose mode
toggle_verbose_mode() {
    local current
    current=$(get_verbose_mode)

    if [[ "$current" == "compact" ]]; then
        set_verbose_mode "verbose"
        echo "verbose"
    else
        set_verbose_mode "compact"
        echo "compact"
    fi
}

# Generate structured summary for an agent from protocol message
# Usage: generate_agent_summary <agent_name>
generate_agent_summary() {
    local agent="$1"
    local protocol_msg
    protocol_msg=$(blackboard_get "agent_protocol_${agent}" 2>/dev/null || echo "")

    if [[ -z "$protocol_msg" ]]; then
        # Fallback to old-style progress data
        local progress_json
        progress_json=$(blackboard_get "agent_progress_${agent}" 2>/dev/null || echo "")
        if [[ -n "$progress_json" ]]; then
            local pct step
            pct=$(echo "$progress_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('pct', 0))" 2>/dev/null || echo "0")
            step=$(echo "$progress_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('step', 'idle'))" 2>/dev/null || echo "idle")
            echo "$agent: ${pct}% — $step"
        else
            echo "$agent: idle"
        fi
        return
    fi

    # Parse structured protocol message
    local msg_type pct track step phase eta detail err
    msg_type=$(echo "$protocol_msg" | python3 -c "import json,sys; print(json.load(sys.stdin).get('t', ''))" 2>/dev/null || echo "")
    pct=$(echo "$protocol_msg" | python3 -c "import json,sys; print(json.load(sys.stdin).get('pct', 0))" 2>/dev/null || echo "0")
    track=$(echo "$protocol_msg" | python3 -c "import json,sys; print(json.load(sys.stdin).get('track', ''))" 2>/dev/null || echo "")
    step=$(echo "$protocol_msg" | python3 -c "import json,sys; print(json.load(sys.stdin).get('step', ''))" 2>/dev/null || echo "")
    phase=$(echo "$protocol_msg" | python3 -c "import json,sys; print(json.load(sys.stdin).get('phase', ''))" 2>/dev/null || echo "")
    eta=$(echo "$protocol_msg" | python3 -c "import json,sys; print(json.load(sys.stdin).get('eta', 0))" 2>/dev/null || echo "0")
    detail=$(echo "$protocol_msg" | python3 -c "import json,sys; print(json.load(sys.stdin).get('detail', ''))" 2>/dev/null || echo "")
    err=$(echo "$protocol_msg" | python3 -c "import json,sys; print(json.load(sys.stdin).get('err', ''))" 2>/dev/null || echo "")

    # Generate human-readable summary
    case "$msg_type" in
        status)
            local summary="$agent: ${pct}% on $track — $step"
            if [[ "$eta" -gt 0 ]]; then
                local mins=$((eta / 60))
                if [[ $mins -gt 0 ]]; then
                    summary+=" (~${mins}m remaining)"
                else
                    summary+=" (~${eta}s remaining)"
                fi
            fi
            echo "$summary"
            ;;
        error)
            echo "⚠ $agent: $err on $track — $detail"
            ;;
        complete)
            echo "✅ $agent completed $track — $detail"
            ;;
        heartbeat)
            echo "💓 $agent: alive"
            ;;
        *)
            echo "$agent: $msg_type"
            ;;
    esac
}

# Render fleet status in compact mode (structured summaries)
render_compact_fleet_status() {
    echo -e "${BLUE}=== Fleet Status (Compact Mode) ===${NC}"

    local health_keys
    health_keys=$(blackboard_list "fleet_health_" 2>/dev/null || echo "")

    if [[ -z "$health_keys" ]]; then
        echo "  No active agents detected."
        return
    fi

    local current_time
    current_time=$(date +%s)

    while IFS='|' read -r key health_json; do
        if [[ -n "$key" ]]; then
            local name="${key#fleet_health_}"
            local display_name
            display_name=$(echo "$name" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g')

            # Generate structured summary
            local summary
            summary=$(generate_agent_summary "$name")

            # Get status color
            local status
            status=$(echo "$health_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status', 'unknown'))" 2>/dev/null || echo "unknown")
            local last_ts
            last_ts=$(echo "$health_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ts', 0))" 2>/dev/null || echo "0")

            local status_color="${GREEN}"
            if [[ "$status" == "error" || "$status" == "crashed" || "$status" == "stale" ]]; then
                status_color="${RED}"
            fi
            if (( current_time - last_ts > 60 )); then
                status="stale"
                status_color="${RED}"
            fi

            printf "  [${status_color}%-8s${NC}] %s\n" "$status" "$summary"
        fi
    done <<< "$health_keys"
}

# Render fleet status in verbose mode (full agent output)
render_verbose_fleet_status() {
    echo -e "${BLUE}=== Fleet Status (Verbose Mode) ===${NC}"
    echo "  Showing full agent output streams..."
    echo "  (Agents are running in separate tmux panes)"

    # List active agents with their protocol messages
    local health_keys
    health_keys=$(blackboard_list "fleet_health_" 2>/dev/null || echo "")

    if [[ -z "$health_keys" ]]; then
        echo "  No active agents detected."
        return
    fi

    while IFS='|' read -r key health_json; do
        if [[ -n "$key" ]]; then
            local name="${key#fleet_health_}"
            local protocol_msg
            protocol_msg=$(blackboard_get "agent_protocol_${name}" 2>/dev/null || echo "")

            echo ""
            echo -e "${YELLOW}--- $name (latest protocol message) ---${NC}"
            if [[ -n "$protocol_msg" ]]; then
                echo "$protocol_msg" | python3 -m json.tool 2>/dev/null || echo "$protocol_msg"
            else
                echo "  No protocol messages received"
            fi
        fi
    done <<< "$health_keys"
}

# Main command handler
main() {
    local command="${1:-status}"
    shift || true

    case "$command" in
        toggle)
            local new_mode
            new_mode=$(toggle_verbose_mode)
            echo -e "${GREEN}✓ Dashboard mode: ${new_mode}${NC}"
            ;;
        status)
            local mode
            mode=$(get_verbose_mode)
            echo -e "${BLUE}Dashboard mode: ${mode}${NC}"
            ;;
        set)
            local mode="${1:-}"
            if [[ -z "$mode" ]]; then
                echo "Error: Mode required (compact/verbose)" >&2
                exit 1
            fi
            set_verbose_mode "$mode"
            echo -e "${GREEN}✓ Dashboard mode: ${mode}${NC}"
            ;;
        render)
            local mode
            mode=$(get_verbose_mode)
            if [[ "$mode" == "verbose" ]]; then
                render_verbose_fleet_status
            else
                render_compact_fleet_status
            fi
            ;;
        help|--help|-h)
            echo "Usage: bash verbose-toggle.sh <command>"
            echo ""
            echo "Commands:"
            echo "  toggle        Toggle between compact and verbose mode"
            echo "  status        Show current mode"
            echo "  set <mode>    Set mode (compact/verbose)"
            echo "  render        Render fleet status in current mode"
            echo "  help          Show this help"
            ;;
        *)
            echo "Error: Unknown command: $command" >&2
            main help
            exit 1
            ;;
    esac
}

main "$@"
