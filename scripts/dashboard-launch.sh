#!/usr/bin/env bash
# HCOM Unified Dashboard - v2.3 (Unified Command Center)
# Implements a centralized monitoring and command layout

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
    print_info "Creating Unified Command Center..."

    # Step 1: Initialize hcom daemon and relay worker
    # Resolve hcom path for use in tmux
    local hcom_bin=$(command -v hcom || echo "$HOME/.local/bin/hcom")
    if [ ! -x "$hcom_bin" ]; then
        hcom_bin="hcom"
    fi

    # Ensure hooks are installed for status tracking
    if ! $hcom_bin hooks status 2>/dev/null | grep -q "installed"; then
        $hcom_bin hooks add all > /dev/null 2>&1 || true
    fi

    # Start relay daemon if relay is enabled
    if $hcom_bin config relay_enabled --json 2>/dev/null | grep -q "true"; then
        $hcom_bin relay daemon start > /dev/null 2>&1 || true
    fi

    # Initialize Atari Integration
    bash "$SCRIPT_DIR/init-atari-constants.sh" > /dev/null 2>&1 || true
    bash "$SCRIPT_DIR/hcom-atari-sync.sh" > /dev/null 2>&1 || true

    sleep 1

    # Step 2: Create session with hcom TUI
    tmux new-session -d -s $SESSION -n "dashboard" "$hcom_bin"
    
    if ! tmux has-session -t $SESSION 2>/dev/null; then
        print_warning "Failed to create tmux session."
        exit 1
    fi

    tmux set-option -g mouse on
    tmux set-option -g pane-border-status top
    tmux set-option -g pane-border-format "#{?pane_active,#[reverse],}#{pane_index}#[default] [#{@agent_name}] \"#{pane_title}\""
    tmux set-option -g allow-rename off

    # Step 3: Setup pane list for Right Column
    local right_panes=()
    if [ "${WITH_CONDUCTOR:-false}" == "true" ]; then
        right_panes+=("conductor")
    fi
    
    [ "${WITH_GEMINI:-true}" == "true" ] && right_panes+=("gemini")
    [ "${WITH_QWEN:-true}" == "true" ] && right_panes+=("qwen")
    [ "${WITH_VLLM:-false}" == "true" ] && right_panes+=("vllm")
    [ "${WITH_DEEPSEEK:-false}" == "true" ] && right_panes+=("deepseek")
    [ "${WITH_CLAUDE:-false}" == "true" ] && right_panes+=("claude")
    [ "${WITH_NEMO:-false}" == "true" ] && right_panes+=("nemo")

    local num_right_panes=${#right_panes[@]}
    
    # Step 4: Layout Creation
    
    # 4a. Create Console Pane (Bottom)
    local console_idx=-1
    if [ "${WITH_CONSOLE:-true}" == "true" ]; then
        tmux split-window -v -t "$SESSION:dashboard.0" -l 5 -c "$PWD"
        console_idx=1
    fi
    
    # 4b. Create Right Column
    # Split Pane 0 (HCOM) vertically to create Right Column
    tmux split-window -h -t "$SESSION:dashboard.0" -c "$PWD"
    local right_col_start_idx=1
    [ $console_idx -eq 1 ] && right_col_start_idx=2
    
    # 4c. Split Right Column for components
    if [ $num_right_panes -gt 1 ]; then
        for ((i=1; i<num_right_panes; i++)); do
            # Indices shift as we split. Splitting the rightmost pane creates a vertical stack.
            tmux split-window -v -t "$SESSION:dashboard.$right_col_start_idx" -c "$PWD"
        done
    fi
    
    # 4d. Finalize Geometry
    tmux select-layout -t "$SESSION:dashboard" "main-vertical"
    tmux resize-pane -t "$SESSION:dashboard.0" -x 80
    if [ $console_idx -ne -1 ]; then
        tmux resize-pane -t "$SESSION:dashboard.$console_idx" -y 5
    fi

    # Step 5: Launch Console
    if [ $console_idx -ne -1 ]; then
        local user_name="user_$(whoami)"
        print_info "Initializing Console..."
        tmux send-keys -t "$SESSION:dashboard.$console_idx" "export HCOM_NAME=$user_name && hcom start --as $user_name" C-m
        tmux send-keys -t "$SESSION:dashboard.$console_idx" "alias s='hcom send @conductor -- \"!status\"'" C-m
        tmux send-keys -t "$SESSION:dashboard.$console_idx" "alias t='hcom send @conductor -- \"!test\"'" C-m
        tmux send-keys -t "$SESSION:dashboard.$console_idx" "alias b='hcom send @conductor -- \"!build\"'" C-m
        tmux send-keys -t "$SESSION:dashboard.$console_idx" "clear" C-m
        
        tmux set-option -t "$SESSION:dashboard.$console_idx" -p @agent_name "CONSOLE"
        tmux select-pane -t "$SESSION:dashboard.$console_idx" -T "User Console ($user_name)"
    fi

    # Step 6: Launch Right Column Components
    for i in "${!right_panes[@]}"; do
        local component="${right_panes[$i]}"
        local pane_idx=$((i + right_col_start_idx))
        local cmd=""
        local agent_name=""
        local title=""

        case $component in
            conductor)
                cmd="bash $SCRIPT_DIR/conductor-workflow.sh"
                agent_name="conductor_dev"
                title="Conductor"
                ;;
            qwen)
                cmd="bash $SCRIPT_DIR/qwen-hcom.sh"
                agent_name="qwen_dev"
                title="Qwen"
                ;;
            gemini)
                cmd="bash $SCRIPT_DIR/gemini-hcom.sh"
                agent_name="gemini_dev"
                title="Gemini"
                ;;
            vllm)
                cmd="bash $SCRIPT_DIR/vllm-hcom.sh"
                agent_name="vllm_dev"
                title="vLLM"
                ;;
            deepseek)
                cmd="bash $SCRIPT_DIR/deepseek-hcom.sh"
                agent_name="deepseek_dev"
                title="DeepSeek"
                ;;
            claude)
                cmd="bash $SCRIPT_DIR/claude-hcom.sh"
                agent_name="claude_dev"
                title="Claude"
                ;;
            nemo)
                cmd="bash $SCRIPT_DIR/nemo-hcom.sh"
                agent_name="nemo_dev"
                title="NeMo"
                ;;
        esac

        print_info "Launching $title in pane $pane_idx..."
        $hcom_bin config -i "$agent_name" tag "$component" > /dev/null 2>&1 || true

        sleep 1.0
        tmux send-keys -t "$SESSION:dashboard.$pane_idx" "export HCOM_NAME=$agent_name && $cmd" C-m
        
        tmux set-option -t "$SESSION:dashboard.$pane_idx" -p @agent_name "$(tr '[:lower:]' '[:upper:]' <<< ${title})"
        tmux select-pane -t "$SESSION:dashboard.$pane_idx" -T "$title"
        (sleep 2.0 && tmux select-pane -t "$SESSION:dashboard.$pane_idx" -T "$title") &
    done

    # Step 7: Finalize HCOM Pane
    tmux set-option -t "$SESSION:dashboard.0" -p @agent_name "HCOM"
    tmux select-pane -t "$SESSION:dashboard.0" -T "hcom TUI"
    
    # Always focus the Console if it exists, otherwise HCOM
    if [ $console_idx -ne -1 ]; then
        tmux select-pane -t "$SESSION:dashboard.$console_idx"
    else
        tmux select-pane -t "$SESSION:dashboard.0"
    fi

    # Step 8: Optional Bridge window
    if [ "${WITH_BRIDGE:-false}" == "true" ]; then
        tmux new-window -d -t $SESSION -n "bridge" "bash $SCRIPT_DIR/hcom-chat-bridge.sh"
    fi

    print_success "Unified Command Center Online"
    sleep 1
}

attach() {
    print_info "Attaching in 1s..."
    sleep 1
    print_info "Navigation: Ctrl+b Arrow Keys | Ctrl+b z zoom"
    tmux attach -t $SESSION
}

main() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  HCOM Command Center v2.3${NC}"
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
    WITH_CONSOLE=true

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
            --no-console) WITH_CONSOLE=false; shift ;;
            -h|--help)
                echo "Usage: dashboard-launch.sh [options]"
                echo "Options:"
                echo "  --conductor      Include Conductor Log Pane"
                echo "  --no-console     Exclude User Command Console"
                echo "  --add-claude     Include Claude agent"
                echo "  --add-deepseek   Include DeepSeek agent"
                echo "  --add-nemo       Include NVIDIA NeMo agent"
                echo "  --vllm           Include remote vLLM agent"
                echo "  --no-vllm        Exclude remote vLLM agent"
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
