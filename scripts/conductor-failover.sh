#!/usr/bin/env bash
# ai-colab Conductor Failover & Self-Healing (P5.5)
# Monitors conductor health, auto-restarts on failure,
# and promotes healthy agents to temporary conductor if needed.
#
# Usage:
#   bash conductor-failover.sh monitor        # Start monitoring (runs in background)
#   bash conductor-failover.sh check          # Check conductor health now
#   bash conductor-failover.sh restart        # Restart conductor
#   bash conductor-failover.sh promote        # Promote agent to temporary conductor
#   bash conductor-failover.sh status         # Show failover status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Configuration
CONDUCTOR_HEARTBEAT_KEY="conductor_heartbeat"
CONDUCTOR_FAILOVER_KEY="conductor_failover_state"
CONDUCTOR_RESTART_COUNT_KEY="conductor_restart_count"
CONDUCTOR_LAST_START_KEY="conductor_last_start"

MAX_RESTARTS=5
RESTART_DELAYS=(10 30 60 120 120)
HEARTBEAT_TIMEOUT=180  # 3 minutes (3x default 60s interval)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1" >&2; }
log_failover() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$PROJECT_ROOT/logs/failover.log" 2>/dev/null || true; }

# Check if conductor is healthy
check_conductor_health() {
    local last_heartbeat
    last_heartbeat=$(blackboard_get "$CONDUCTOR_HEARTBEAT_KEY" 2>/dev/null || echo "0")

    if [[ -z "$last_heartbeat" || "$last_heartbeat" == "0" ]]; then
        echo "no_heartbeat"
        return 1
    fi

    local now
    now=$(date +%s)
    local age=$((now - last_heartbeat))

    if [[ $age -gt $HEARTBEAT_TIMEOUT ]]; then
        echo "stale_${age}s"
        return 1
    fi

    echo "healthy (${age}s ago)"
    return 0
}

# Get conductor restart count
get_restart_count() {
    blackboard_get "$CONDUCTOR_RESTART_COUNT_KEY" 2>/dev/null || echo "0"
}

# Increment conductor restart count
increment_restart_count() {
    local count
    count=$(get_restart_count)
    count=$((count + 1))
    blackboard_set "$CONDUCTOR_RESTART_COUNT_KEY" "$count"
    echo "$count"
}

# Reset conductor restart count
reset_restart_count() {
    blackboard_set "$CONDUCTOR_RESTART_COUNT_KEY" "0"
    blackboard_set "$CONDUCTOR_LAST_START_KEY" "$(date +%s)"
}

# Restart conductor
restart_conductor() {
    local restart_count
    restart_count=$(increment_restart_count)

    if [[ $restart_count -gt $MAX_RESTARTS ]]; then
        print_error "Max restart attempts ($MAX_RESTARTS) exceeded"
        log_failover "MAX_RESTARTS_EXCEEDED: restart_count=$restart_count"
        return 1
    fi

    local delay=${RESTART_DELAYS[$((restart_count - 1))]:-120}
    print_warning "Restarting conductor (attempt $restart_count/$MAX_RESTARTS) in ${delay}s..."
    log_failover "RESTART_ATTEMPT: attempt=$restart_count delay=${delay}s"

    sleep "$delay"

    # Find conductor launch script
    local conductor_script="$SCRIPT_DIR/conductor-workflow.sh"

    if [[ -f "$conductor_script" ]]; then
        print_info "Starting conductor..."
        nohup bash "$conductor_script" >> "$PROJECT_ROOT/logs/conductor-failover.log" 2>&1 &
        local conductor_pid=$!

        # Wait for conductor to start
        sleep 5

        # Check if conductor started successfully
        local health
        health=$(check_conductor_health) || true

        if [[ "$health" == healthy* ]]; then
            print_success "Conductor restarted successfully (PID: $conductor_pid)"
            log_failover "RESTART_SUCCESS: pid=$conductor_pid"
            reset_restart_count
            return 0
        else
            print_error "Conductor failed to restart (health: $health)"
            log_failover "RESTART_FAILED: health=$health"
            return 1
        fi
    else
        print_error "Conductor script not found: $conductor_script"
        log_failover "RESTART_FAILED: script_not_found=$conductor_script"
        return 1
    fi
}

# Find healthiest agent to promote
find_healthiest_agent() {
    local agents=("gemini" "qwen" "claude" "deepseek")

    for agent in "${agents[@]}"; do
        local health
        health=$(blackboard_get "fleet_health_$agent" 2>/dev/null || echo "")

        if [[ -n "$health" ]] && echo "$health" | grep -q '"status":"ready"'; then
            echo "$agent"
            return 0
        fi
    done

    echo ""
    return 1
}

# Promote agent to temporary conductor
promote_agent() {
    print_warning "Attempting to promote healthy agent to temporary conductor..."
    log_failover "PROMOTION_START"

    local agent
    agent=$(find_healthiest_agent) || true

    if [[ -z "$agent" ]]; then
        print_error "No healthy agents available for promotion"
        log_failover "PROMOTION_FAILED: no_healthy_agents"
        return 1
    fi

    print_info "Promoting $agent to temporary conductor..."
    log_failover "PROMOTION_SUCCESS: agent=$agent"

    # Set failover state
    blackboard_set "$CONDUCTOR_FAILOVER_KEY" "{\"promoted_agent\":\"$agent\",\"timestamp\":$(date +%s),\"reason\":\"conductor_unreachable\"}"

    # TODO: Implement minimal conductor functionality for promoted agent
    # For now, this is a placeholder for future implementation
    print_success "Agent $agent marked as temporary conductor"
    print_info "Note: Full conductor functionality for promoted agents is pending implementation"

    return 0
}

# Show failover status
show_status() {
    local health
    health=$(check_conductor_health) || true

    local restart_count
    restart_count=$(get_restart_count)

    local failover_state
    failover_state=$(blackboard_get "$CONDUCTOR_FAILOVER_KEY" 2>/dev/null || echo "{}")

    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Conductor Failover Status                          ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Conductor Health:${NC} $health"
    echo -e "${BLUE}Restart Count:${NC} $restart_count / $MAX_RESTARTS"
    echo -e "${BLUE}Failover State:${NC} $failover_state"
    echo ""
}

# Monitor conductor health (runs in background)
monitor_loop() {
    print_info "Starting conductor health monitor..."
    log_failover "MONITOR_START"

    while true; do
        local health
        health=$(check_conductor_health) || true

        if [[ "$health" != healthy* ]]; then
            print_warning "Conductor unhealthy: $health"
            log_failover "CONDUCTOR_UNHEALTHY: health=$health"

            # Try to restart
            if restart_conductor; then
                print_success "Conductor recovered"
                log_failover "CONDUCTOR_RECOVERED"
            else
                print_error "Conductor restart failed, attempting promotion..."
                log_failover "CONDUCTOR_RESTART_FAILED"

                # Try to promote agent
                if promote_agent; then
                    print_success "Agent promoted to temporary conductor"
                    log_failover "AGENT_PROMOTED"
                else
                    print_error "All failover mechanisms failed"
                    log_failover "ALL_FAILOVERS_FAILED"
                fi
            fi
        fi

        sleep 60  # Check every minute
    done
}

# ============================================================
# Main
# ============================================================

main() {
    local command="${1:-help}"

    case "$command" in
        monitor)
            monitor_loop
            ;;
        check)
            show_status
            ;;
        restart)
            restart_conductor
            ;;
        promote)
            promote_agent
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            echo ""
            echo -e "${BLUE}Usage:${NC}"
            echo "  bash conductor-failover.sh <command>"
            echo ""
            echo -e "${BLUE}Commands:${NC}"
            echo "  monitor   Start health monitoring loop (runs in background)"
            echo "  check     Check conductor health now"
            echo "  restart   Restart conductor manually"
            echo "  promote   Promote healthy agent to temporary conductor"
            echo "  status    Show failover status"
            echo "  help      Show this help message"
            ;;
        *)
            print_error "Unknown command: $command"
            main help
            exit 1
            ;;
    esac
}

main "$@"
