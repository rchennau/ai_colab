#!/usr/bin/env bash
# HCOM Unified Dashboard - v2 Fix
# Uses hcom-native agent launching for proper status tracking
#
# Key changes:
# 1. Launch agents using hcom's native launch system
# 2. Agents stay connected via hcom PTY tracking
# 3. Real-time status updates in hcom TUI

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

SESSION="hcom-dashboard"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}!${NC} $1"; }

check_prereqs() {
    if ! has_command tmux; then
        echo -e "${RED}Error: tmux not found.${NC}"
        echo -e "Please install tmux to use the dashboard."
        exit 1
    fi
    if ! check_hcom; then
        echo -e "${RED}Error: hcom is required for the dashboard.${NC}"
        exit 1
    fi
}

reconnect() {
    if tmux has-session -t $SESSION 2>/dev/null; then
        print_info "Attaching to existing dashboard session..."
        attach
        exit 0
    fi
}

create_dashboard() {
    print_info "Creating dashboard session..."

    # Step 1: Initialize hcom daemon and relay worker
    print_info "Initializing hcom daemon and relay worker..."
    hcom start > /dev/null 2>&1 || true
    # Start relay daemon if relay is enabled
    if hcom config relay_enabled --json 2>/dev/null | grep -q "true"; then
        hcom relay daemon start > /dev/null 2>&1 || true
        print_success "Relay daemon started"
    fi

    # Initialize Atari Integration
    print_info "Initializing Deep Atari Integration..."
    bash "$SCRIPT_DIR/init-atari-constants.sh" > /dev/null 2>&1 || true
    bash "$SCRIPT_DIR/hcom-atari-sync.sh" > /dev/null 2>&1 || true
    print_success "Hardware context initialized"

    sleep 1

    # Step 2: Create session with hcom TUI
    tmux new-session -d -s $SESSION -n "dashboard" "hcom"
    tmux set-option -g mouse on

    # Optional: Start Conductor workflow in background
    if [ "${WITH_CONDUCTOR:-false}" == "true" ]; then
        tmux new-window -d -t $SESSION -n "conductor" "bash $SCRIPT_DIR/conductor-workflow.sh"
        print_success "Conductor agent started"
    fi

    # Optional: Start Messenger Bridge
    if [ "${WITH_BRIDGE:-false}" == "true" ]; then
        tmux new-window -d -t $SESSION -n "bridge" "bash $SCRIPT_DIR/hcom-chat-bridge.sh"
        print_success "Messenger Bridge started"
    fi

    # Step 3: Create right column for agents
    tmux split-window -h -t $SESSION:0

    # Step 4: Setup agent panes
    local agents=()
    [ "${WITH_QWEN:-true}" == "true" ] && agents+=("qwen")
    [ "${WITH_GEMINI:-true}" == "true" ] && agents+=("gemini")
    [ "${WITH_DEEPSEEK:-false}" == "true" ] && agents+=("deepseek")
    [ "${WITH_CLAUDE:-false}" == "true" ] && agents+=("claude")
    [ "${WITH_NEMO:-false}" == "true" ] && agents+=("nemo")

    local num_agents=${#agents[@]}
    if [ $num_agents -gt 1 ]; then
        tmux select-pane -t $SESSION:0.1
        for ((i=1; i<$num_agents; i++)); do
            tmux split-window -v -t $SESSION:0.1
        done
        # Balance panes
        tmux select-layout -t $SESSION:0 "main-vertical"
    fi

    # Step 5: Launch selected agents
    for i in "${!agents[@]}"; do
        local agent="${agents[$i]}"
        local pane_idx=$((i + 1))
        local agent_name="${agent}-dev"
        local cmd=""

        case $agent in
            qwen)     cmd="hcom run qwen" ;;
            gemini)   cmd="hcom run gemini-hcom" ;;
            deepseek) cmd="hcom run deepseek" ;;
            claude)   cmd="hcom run claude" ;;
            nemo)     cmd="hcom run nemo" ;;
        esac

        print_info "Launching $agent in pane $pane_idx..."
        tmux send-keys -t $SESSION:0.$pane_idx "export HCOM_NAME=$agent_name && $cmd" C-m
        tmux select-pane -t $SESSION:0.$pane_idx -T "$agent CLI"
    done

    # Step 6: Set pane sizes
    tmux select-pane -t $SESSION:0.0
    tmux resize-pane -t $SESSION:0.0 -x 80
    tmux select-pane -t $SESSION:0.0 -T "hcom TUI"

    # Step 7: Select hcom pane
    tmux select-pane -t $SESSION:0.0

    print_success "Dashboard created with $num_agents agents"
}

attach() {
    print_info "Attaching to dashboard..."
    print_info "Navigation: Ctrl+b Arrow Keys | Ctrl+b z zoom"
    tmux attach -t $SESSION
}

main() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  HCOM Unified Dashboard v2.1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Defaults
    WITH_QWEN=true
    WITH_GEMINI=true
    WITH_DEEPSEEK=false
    WITH_CLAUDE=false
    WITH_NEMO=false
    WITH_CONDUCTOR=false
    WITH_BRIDGE=false

    # Parse command line flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --add-claude) WITH_CLAUDE=true; shift ;;
            --add-deepseek) WITH_DEEPSEEK=true; shift ;;
            --add-nemo) WITH_NEMO=true; shift ;;
            --conductor) WITH_CONDUCTOR=true; shift ;;
            --bridge) WITH_BRIDGE=true; shift ;;
            --no-qwen) WITH_QWEN=false; shift ;;
            --no-gemini) WITH_GEMINI=false; shift ;;
            -h|--help)
                echo "Usage: dashboard-launch.sh [options]"
                echo "Options:"
                echo "  --add-claude     Include Claude agent"
                echo "  --add-deepseek   Include DeepSeek agent"
                echo "  --add-nemo       Include NVIDIA NeMo agent"
                echo "  --conductor      Include Conductor automation"
                echo "  --bridge         Include Google Chat bridge"
                echo "  --no-qwen        Exclude Qwen agent"
                echo "  --no-gemini      Exclude Gemini agent"
                exit 0
                ;;
            *) shift ;;
        esac
    done

    check_prereqs
    reconnect
    create_dashboard
    attach
}

main "$@"
