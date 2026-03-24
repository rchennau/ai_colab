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

    # Initialize Atari Integration (Addon)
    if [[ "${ENABLE_ATARI_LX:-false}" == "true" ]]; then
        print_info "Initializing Atari-LX Module..."
        bash "$PROJECT_ROOT/modules/atari-lx/scripts/init-atari-constants.sh" > /dev/null 2>&1 || true
        bash "$PROJECT_ROOT/modules/atari-lx/scripts/hcom-atari-sync.sh" > /dev/null 2>&1 || true
    fi

    sleep 1

    # Step 2: Create session with hcom TUI
    tmux new-session -d -s $SESSION -n "dashboard" "$hcom_bin"
    
    if ! tmux has-session -t $SESSION 2>/dev/null; then
        print_warning "Failed to create tmux session."
        exit 1
    fi

    tmux set-option -g mouse on
    tmux set-option -g pane-border-status top
    tmux set-option -g pane-border-format "#{?pane_active,#[reverse],} #P #[default] [#{@agent_name}] #{=20:pane_title} "
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
    [ "${WITH_NEMOCLAW:-false}" == "true" ] && right_panes+=("nemoclaw")

    local num_right_panes=${#right_panes[@]}
    
    # Step 4: Layout Creation
    
    # 4a. Create Console Pane (Bottom)
    local console_id=""
    if [ "${WITH_CONSOLE:-true}" == "true" ]; then
        console_id=$(tmux split-window -v -t "$SESSION:dashboard.0" -l 5 -c "$PWD" -P -F "#{pane_id}")
    fi
    
    # 4b. Create Right Column
    # Split Pane 0 (HCOM) horizontally to create Right Column
    local right_col_id=$(tmux split-window -h -t "$SESSION:dashboard.0" -c "$PWD" -P -F "#{pane_id}")
    
    # 4c. Split Right Column for components
    local agent_pane_ids=("$right_col_id")
    if [ $num_right_panes -gt 1 ]; then
        local current_pane_id="$right_col_id"
        for ((i=1; i<num_right_panes; i++)); do
            current_pane_id=$(tmux split-window -v -t "$current_pane_id" -c "$PWD" -P -F "#{pane_id}")
            agent_pane_ids+=("$current_pane_id")
            # Balancing space is critical to avoid "no space for new pane"
            tmux select-layout -t "$SESSION:dashboard" tiled >/dev/null 2>&1 || true
        done
    fi
    
    # 4d. Finalize Geometry
    # Re-apply main-vertical to get the HCOM on left, others on right
    tmux select-layout -t "$SESSION:dashboard" "main-vertical"
    tmux resize-pane -t "$SESSION:dashboard.0" -x 80
    
    if [ -n "$console_id" ]; then
        tmux resize-pane -t "$console_id" -y 5
    fi

    # Step 5: Launch Console
    if [ -n "$console_id" ]; then
        local console_idx=$(tmux display-message -p -t "$console_id" "#{pane_index}")
        local user_name="user_$(whoami)"
        print_info "Initializing Console in pane $console_idx..."
        tmux send-keys -t "$console_id" "export HCOM_NAME=$user_name && hcom start --as \$HCOM_NAME" C-m
        tmux send-keys -t "$console_id" "alias s='hcom send --name \$HCOM_NAME @conductor -- \"!status\"'" C-m
        tmux send-keys -t "$console_id" "alias t='hcom send --name \$HCOM_NAME @conductor -- \"!test\"'" C-m
        tmux send-keys -t "$console_id" "alias b='hcom send --name \$HCOM_NAME @conductor -- \"!build\"'" C-m
        tmux send-keys -t "$console_id" "clear" C-m
        tmux send-keys -t "$console_id" "echo -e \"${BLUE}╔══════════════════════════════════════════════╗${NC}\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"${BLUE}║           ai-colab HCOM User Console         ║${NC}\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"${BLUE}╚══════════════════════════════════════════════╝${NC}\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"Logged in as: ${GREEN}$user_name${NC}\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"${YELLOW}Available Conductor Commands:${NC}\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"  ${GREEN}s${NC} (!status)      - Get project health & progress\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"  ${GREEN}t${NC} (!test)        - Run all automated tests\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"  ${GREEN}b${NC} (!build)       - Build project and integrated apps\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"  !kb <query>      - Search architectural knowledge base\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"  !git-sync        - Pull latest changes from remote\"" C-m
        
        if [[ "${ENABLE_ATARI_LX:-false}" == "true" ]]; then
            tmux send-keys -t "$console_id" "echo -e \"${YELLOW}Atari-LX Commands:${NC}\"" C-m
            tmux send-keys -t "$console_id" "echo -e \"  !screenshot      - Capture current emulator state\"" C-m
            tmux send-keys -t "$console_id" "echo -e \"  !memory-map      - View visual memory allocation\"" C-m
            tmux send-keys -t "$console_id" "echo -e \"  !profile <file>  - Profile code performance (cycles)\"" C-m
            tmux send-keys -t "$console_id" "echo -e \"  !perf-trend <rt> - View historical performance trend\"" C-m
        fi
        
        tmux send-keys -t "$console_id" "echo -e \"  !help            - Show all available commands\"" C-m
        tmux send-keys -t "$console_id" "echo \"\"" C-m
        
        tmux set-option -t "$console_id" -p @agent_name "CONSOLE"
        tmux select-pane -t "$console_id" -T "User Console ($user_name)"
    fi

    # Step 6: Launch Right Column Components
    for i in "${!right_panes[@]}"; do
        local component="${right_panes[$i]}"
        local pane_id="${agent_pane_ids[$i]}"
        local pane_idx=$(tmux display-message -p -t "$pane_id" "#{pane_index}")
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
            nemoclaw)
                cmd="bash $SCRIPT_DIR/nemoclaw-hcom.sh"
                agent_name="nemoclaw"
                title="nemoclaw"
                ;;
        esac

        print_info "Launching $title in pane $pane_idx..."
        $hcom_bin config -i "$agent_name" tag "$component" > /dev/null 2>&1 || true

        sleep 1.0
        tmux send-keys -t "$pane_id" "export HCOM_NAME=$agent_name && $cmd" C-m
        
        tmux set-option -t "$pane_id" -p @agent_name "$(tr '[:lower:]' '[:upper:]' <<< ${title})"
        tmux select-pane -t "$pane_id" -T "$title"
        (sleep 2.0 && tmux select-pane -t "$pane_id" -T "$title") &
    done

    # Step 7: Finalize HCOM Pane
    tmux set-option -t "$SESSION:dashboard.0" -p @agent_name "HCOM"
    tmux select-pane -t "$SESSION:dashboard.0" -T "hcom TUI"
    
    # Always focus the Console if it exists, otherwise HCOM
    if [ -n "$console_id" ]; then
        tmux select-pane -t "$console_id"
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
    WITH_NEMOCLAW=false
    WITH_CONDUCTOR=false
    WITH_BRIDGE=false
    WITH_CONSOLE=true

    # Parse command line flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --add-claude) WITH_CLAUDE=true; shift ;;
            --add-deepseek) WITH_DEEPSEEK=true; shift ;;
            --add-nemo) WITH_NEMO=true; shift ;;
            --add-nemoclaw) WITH_NEMOCLAW=true; shift ;;
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
                echo "  --add-nemoclaw   Include NVIDIA NIM nemoclaw"
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
