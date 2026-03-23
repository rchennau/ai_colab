#!/usr/bin/env bash
# HCOM Unified Dashboard - v2.2 Fix
# Uses hcom-native agent launching for proper status tracking

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

    # Ensure hooks are installed for status tracking
    if ! hcom hooks status | grep -q "installed"; then
        print_info "Installing hcom hooks for agent status tracking..."
        hcom hooks add all > /dev/null 2>&1 || true
    fi

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
    tmux set-option -g pane-border-status top
    # Update pane-border-format to include the custom @agent_name option
    tmux set-option -g pane-border-format "#{?pane_active,#[reverse],}#{pane_index}#[default] [#{@agent_name}] \"#{pane_title}\""
    # Prevent tmux from auto-renaming panes based on running command
    tmux set-option -g allow-rename off

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

    # Step 3: Setup agent list
    local agents=()
    [ "${WITH_GEMINI:-true}" == "true" ] && agents+=("gemini")
    [ "${WITH_QWEN:-true}" == "true" ] && agents+=("qwen")
    [ "${WITH_VLLM:-false}" == "true" ] && agents+=("vllm")
    [ "${WITH_DEEPSEEK:-false}" == "true" ] && agents+=("deepseek")
    [ "${WITH_CLAUDE:-false}" == "true" ] && agents+=("claude")
    [ "${WITH_NEMO:-false}" == "true" ] && agents+=("nemo")

    local num_agents=${#agents[@]}
    
    # Step 4: Create agent panes
    if [ $num_agents -gt 0 ]; then
        # First split creates the right column
        tmux split-window -h -t $SESSION:0
        
        # Then split the right column into num_agents rows
        if [ $num_agents -gt 1 ]; then
            for ((i=1; i<num_agents; i++)); do
                # Split the LAST created pane to get a vertical stack in order
                tmux split-window -v -t $SESSION:0.$i
            done
        fi
        
        # Apply layout to ensure all panes are sized reasonably
        tmux select-layout -t $SESSION:0 "main-vertical"
        # Resize main pane to exactly 80 columns
        tmux resize-pane -t $SESSION:0.0 -x 80
    fi

    # Step 5: Launch selected agents
    for i in "${!agents[@]}"; do
        local agent="${agents[$i]}"
        local pane_idx=$((i + 1))
        local agent_name="${agent}_dev"
        local cmd=""

        case $agent in
            qwen)     cmd="bash $SCRIPT_DIR/qwen-hcom.sh" ;;
            gemini)   cmd="bash $SCRIPT_DIR/gemini-hcom.sh" ;;
            vllm)     cmd="bash $SCRIPT_DIR/vllm-hcom.sh" ;;
            deepseek) cmd="bash $SCRIPT_DIR/deepseek-hcom.sh" ;;
            claude)   cmd="bash $SCRIPT_DIR/claude-hcom.sh" ;;
            nemo)     cmd="bash $SCRIPT_DIR/nemo-hcom.sh" ;;
        esac

        print_info "Launching $agent in pane $pane_idx..."
        # Use a small sleep to ensure tmux is ready for send-keys
        sleep 0.2
        
        # Prepare environment variables to pass
        local env_vars="export HCOM_NAME=$agent_name"
        if [ "$agent" == "vllm" ] && [ -n "${VLLM_BASE_URL:-}" ]; then
            env_vars+=" VLLM_BASE_URL=\"$VLLM_BASE_URL\""
        fi
        if [ "$agent" == "nemo" ] && [ -n "${NEMO_BASE_URL:-}" ]; then
            env_vars+=" NEMO_BASE_URL=\"$NEMO_BASE_URL\""
        fi

        tmux send-keys -t $SESSION:0.$pane_idx "$env_vars && $cmd" C-m
        
        # Set persistent agent name and initial title
        local title_case_agent="$(tr '[:lower:]' '[:upper:]' <<< ${agent:0:1})${agent:1}"
        tmux set-option -t $SESSION:0.$pane_idx -p @agent_name "$title_case_agent"
        tmux select-pane -t $SESSION:0.$pane_idx -T "$title_case_agent"
        
        # Re-apply title after brief delay to prevent shell from overwriting it
        (sleep 1 && tmux select-pane -t $SESSION:0.$pane_idx -T "$title_case_agent") &
    done

    # Step 6: Select hcom pane
    tmux set-option -t $SESSION:0.0 -p @agent_name "HCOM"
    tmux select-pane -t $SESSION:0.0 -T "hcom TUI"
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
    echo -e "${BLUE}  HCOM Unified Dashboard v2.2${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Defaults
    WITH_QWEN=true
    WITH_GEMINI=true
    WITH_VLLM=true
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
            --vllm) WITH_VLLM=true; shift ;;
            --no-vllm) WITH_VLLM=false; shift ;;
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
                echo "  --vllm           Include remote vLLM agent"
                echo "  --no-vllm        Exclude remote vLLM agent"
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
