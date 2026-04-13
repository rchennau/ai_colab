#!/usr/bin/env bash
# ai-colab Conductor Watchdog (P25.2)
# Monitors conductor process and auto-restarts on crash/hang
# Uses exponential backoff: 5s → 15s → 30s → 60s
#
# Usage:
#   bash conductor-watchdog.sh start    # Start monitoring conductor
#   bash conductor-watchdog.sh stop     # Stop monitoring
#   bash conductor-watchdog.sh status   # Check watchdog status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
WATCHDOG_STATE_FILE="/tmp/ai-colab-watchdog.state"
WATCHDOG_PID_FILE="/tmp/ai-colab-watchdog.pid"
CONDUCTOR_PID_FILE="/tmp/ai-colab-conductor.pid"
MAX_RESTARTS=10
BACKOFF_BASE=5
HEARTBEAT_TIMEOUT=90  # seconds before considering conductor stale

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1" >&2; }

# Get backoff delay based on restart count
calc_backoff() {
    local count="${1:-0}"
    local delay=$BACKOFF_BASE

    # Exponential backoff: 5 * 3^(count-1), capped at 60s
    if [[ $count -gt 0 ]]; then
        delay=$((BACKOFF_BASE * (3 ** (count - 1))))
        if [[ $delay -gt 60 ]]; then
            delay=60
        fi
    fi

    echo "$delay"
}

# Check if conductor is running
is_conductor_running() {
    if [[ -f "$CONDUCTOR_PID_FILE" ]]; then
        local pid
        pid=$(cat "$CONDUCTOR_PID_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Check conductor heartbeat
check_conductor_heartbeat() {
    local heartbeat
    heartbeat=$(blackboard_get "conductor_heartbeat" 2>/dev/null || echo "")

    if [[ -z "$heartbeat" ]]; then
        echo "no_heartbeat"
        return 1
    fi

    local ts status
    ts=$(echo "$heartbeat" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ts', 0))" 2>/dev/null || echo "0")
    status=$(echo "$heartbeat" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status', 'unknown'))" 2>/dev/null || echo "unknown")

    local now
    now=$(date +%s)
    local age=$((now - ts))

    if [[ $age -gt $HEARTBEAT_TIMEOUT ]]; then
        echo "stale:${age}s"
        return 1
    fi

    echo "healthy:${status}"
    return 0
}

# Start conductor process
start_conductor() {
    print_info "Starting conductor..."

    # Run conductor in background
    bash "$SCRIPT_DIR/conductor-workflow.sh" &
    local conductor_pid=$!

    # Save PID
    echo "$conductor_pid" > "$CONDUCTOR_PID_FILE"
    print_success "Conductor started (PID: $conductor_pid)"

    return 0
}

# Stop conductor process
stop_conductor() {
    if is_conductor_running; then
        local pid
        pid=$(cat "$CONDUCTOR_PID_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]]; then
            print_info "Stopping conductor (PID: $pid)..."
            kill "$pid" 2>/dev/null || true
            sleep 2
            kill -9 "$pid" 2>/dev/null || true
            rm -f "$CONDUCTOR_PID_FILE"
            print_success "Conductor stopped"
        fi
    fi
}

# Restart conductor with backoff
restart_conductor() {
    local restart_count="${1:-0}"
    local delay
    delay=$(calc_backoff "$restart_count")

    print_warning "Conductor failed. Restarting in ${delay}s (attempt $((restart_count + 1))/$MAX_RESTARTS)..."

    # Wait with backoff
    sleep "$delay"

    # Stop any lingering conductor
    stop_conductor

    # Start conductor
    start_conductor

    # Update state
    echo "$((restart_count + 1))" > "$WATCHDOG_STATE_FILE"
}

# Main watchdog loop
watchdog_loop() {
    print_info "Watchdog starting..."

    local restart_count=0
    if [[ -f "$WATCHDOG_STATE_FILE" ]]; then
        restart_count=$(cat "$WATCHDOG_STATE_FILE" 2>/dev/null || echo "0")
    fi

    # Ensure conductor is running
    if ! is_conductor_running; then
        print_warning "Conductor not running, starting..."
        start_conductor
    fi

    # Main monitoring loop
    while true; do
        sleep 10

        # Check if conductor is still running
        if ! is_conductor_running; then
            print_error "Conductor process died!"

            # Check if we've exceeded max restarts
            if [[ $restart_count -ge $MAX_RESTARTS ]]; then
                print_error "Max restarts ($MAX_RESTARTS) reached. Stopping watchdog."
                blackboard_set "conductor_watchdog_status" "{\"status\":\"stopped\",\"reason\":\"max_restarts\",\"restarts\":$restart_count}" 2>/dev/null || true
                break
            fi

            # Restart with backoff
            restart_conductor "$restart_count"
            restart_count=$((restart_count + 1))
            continue
        fi

        # Check conductor heartbeat
        local hb_status
        hb_status=$(check_conductor_heartbeat)
        local hb_type="${hb_status%%:*}"

        if [[ "$hb_type" == "no_heartbeat" ]]; then
            print_warning "No conductor heartbeat detected"
        elif [[ "$hb_type" == "stale" ]]; then
            local age="${hb_status#*:}"
            print_warning "Conductor heartbeat stale: $age"

            # If heartbeat is very stale, consider restarting
            local age_seconds="${age%s}"
            if [[ $age_seconds -gt $((HEARTBEAT_TIMEOUT * 2)) ]]; then
                print_error "Conductor heartbeat very stale, restarting..."
                stop_conductor
                restart_conductor "$restart_count"
                restart_count=$((restart_count + 1))
            fi
        fi

        # Update watchdog status
        blackboard_set "conductor_watchdog_status" "{\"status\":\"monitoring\",\"restarts\":$restart_count,\"max_restarts\":$MAX_RESTARTS}" 2>/dev/null || true
    done
}

# Start watchdog in background
start_watchdog() {
    # Check if already running
    if [[ -f "$WATCHDOG_PID_FILE" ]]; then
        local pid
        pid=$(cat "$WATCHDOG_PID_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            print_warning "Watchdog already running (PID: $pid)"
            return 0
        fi
    fi

    # Start watchdog
    watchdog_loop &
    local watchdog_pid=$!
    echo "$watchdog_pid" > "$WATCHDOG_PID_FILE"
    print_success "Watchdog started (PID: $watchdog_pid)"

    # Cleanup on exit
    trap 'kill $watchdog_pid 2>/dev/null; rm -f "$WATCHDOG_PID_FILE"' EXIT
}

# Stop watchdog
stop_watchdog() {
    if [[ -f "$WATCHDOG_PID_FILE" ]]; then
        local pid
        pid=$(cat "$WATCHDOG_PID_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]]; then
            print_info "Stopping watchdog (PID: $pid)..."
            kill "$pid" 2>/dev/null || true
            rm -f "$WATCHDOG_PID_FILE"
            print_success "Watchdog stopped"
        fi
    else
        print_info "Watchdog not running"
    fi
}

# Show watchdog status
show_status() {
    local watchdog_running=false
    local conductor_running=false

    if [[ -f "$WATCHDOG_PID_FILE" ]]; then
        local pid
        pid=$(cat "$WATCHDOG_PID_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            watchdog_running=true
        fi
    fi

    if is_conductor_running; then
        conductor_running=true
    fi

    local restart_count=0
    if [[ -f "$WATCHDOG_STATE_FILE" ]]; then
        restart_count=$(cat "$WATCHDOG_STATE_FILE" 2>/dev/null || echo "0")
    fi

    local hb_status="unknown"
    if [[ "$conductor_running" == "true" ]]; then
        hb_status=$(check_conductor_heartbeat)
    fi

    echo ""
    echo -e "${BLUE}=== Conductor Watchdog Status ===${NC}"
    echo ""
    echo "  Watchdog: $([ "$watchdog_running" == "true" ] && echo -e "${GREEN}running${NC}" || echo -e "${RED}stopped${NC}")"
    echo "  Conductor: $([ "$conductor_running" == "true" ] && echo -e "${GREEN}running${NC}" || echo -e "${RED}stopped${NC}")"
    echo "  Restarts: $restart_count / $MAX_RESTARTS"
    echo "  Heartbeat: $hb_status"
    echo ""
}

# Main command handler
main() {
    local command="${1:-status}"

    case "$command" in
        start)
            start_watchdog
            ;;
        stop)
            stop_watchdog
            stop_conductor
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            echo "Usage: bash conductor-watchdog.sh <command>"
            echo ""
            echo "Commands:"
            echo "  start    Start watchdog monitoring"
            echo "  stop     Stop watchdog and conductor"
            echo "  status   Show watchdog status"
            echo "  help     Show this help"
            ;;
        *)
            print_error "Unknown command: $command"
            main help
            exit 1
            ;;
    esac
}

main "$@"
