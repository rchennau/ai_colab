#!/usr/bin/env bash
# HCOM Dashboard - Helper Commands
# Provides status, stop, and utility functions for the dashboard
#
# Usage:
#   dashboard-help.sh status   - Show dashboard status
#   dashboard-help.sh stop     - Stop dashboard session
#   dashboard-help.sh restart  - Restart dashboard session
#   dashboard-help.sh attach   - Attach to existing session
#

set -euo pipefail

SESSION="hcom-dashboard"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

show_status() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  HCOM Dashboard Status${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if tmux has-session -t $SESSION 2>/dev/null; then
        print_status "Dashboard session is running"
        echo ""
        echo "Panes:"
        tmux list-panes -t $SESSION -F "  #{pane_index}: [#{@agent_name}] #{pane_title} - #{pane_current_command}"
        echo ""
        echo "To attach: ~/.hcom/scripts/dashboard-launch.sh"
        echo "To stop:   ~/.hcom/scripts/dashboard-help.sh stop"
    else
        print_warning "Dashboard session is not running"
        echo ""
        echo "To start: ~/.hcom/scripts/dashboard-launch.sh"
    fi
    echo ""
}

stop_dashboard() {
    echo ""
    if tmux has-session -t $SESSION 2>/dev/null; then
        print_warning "Stopping dashboard session..."
        tmux kill-session -t $SESSION
        print_status "Dashboard stopped"
    else
        print_warning "Dashboard not running"
    fi
    echo ""
}

restart_dashboard() {
    if tmux has-session -t $SESSION 2>/dev/null; then
        tmux kill-session -t $SESSION
    fi
    exec ~/.hcom/scripts/dashboard-launch.sh
}

attach_only() {
    if tmux has-session -t $SESSION 2>/dev/null; then
        tmux attach -t $SESSION
    else
        print_error "Dashboard not running. Start with: ~/.hcom/scripts/dashboard-launch.sh"
        exit 1
    fi
}

# Main
case "${1:-status}" in
    status)
        show_status
        ;;
    stop|kill)
        stop_dashboard
        ;;
    restart)
        restart_dashboard
        ;;
    attach|a)
        attach_only
        ;;
    help|--help|-h)
        cat << HELP
HCOM Dashboard Helper

Usage: ~/.hcom/scripts/dashboard-help.sh [command]

Commands:
  status   Show dashboard status (default)
  stop     Stop dashboard session
  restart  Restart dashboard session
  attach   Attach to existing session
  help     Show this help

Quick Commands:
  ~/.hcom/scripts/dashboard-launch.sh    Launch/connect to dashboard
  ~/.hcom/scripts/atari-debate           Start a technical decision debate
HELP
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use 'help' for usage information"
        exit 1
        ;;
esac
