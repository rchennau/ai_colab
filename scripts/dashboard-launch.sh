#!/usr/bin/env bash
# HCOM Unified Dashboard - v2.4 (Enhanced Stability & UX)
# Implements a centralized monitoring and command layout
# Improvements: Better error handling, health checks, pre-flight checks, session recovery

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Ensure PROJECT_ROOT is set for pre-flight checks and components
export PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || echo "$PWD")}"

SESSION="hcom-dashboard"
SESSION_LOCK="/tmp/hcom-dashboard.lock"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
MIN_TERMINAL_WIDTH=80
MIN_TERMINAL_HEIGHT=24
AGENT_STARTUP_DELAY=2
MAX_AGENT_RESTARTS=3

# Counters for agent health (Placeholder for future health monitoring enhancements)
# MAX_AGENT_RESTARTS is defined above but automated restart logic is handled by hcom directly.

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1" >&2; }
print_step() { echo -e "${CYAN}▶${NC} $1"; }

# Pre-flight Checks
preflight_checks() {
    local errors=0
    local warnings=0
    
    print_step "Running pre-flight checks..."
    
    # Check 1: tmux available
    if ! has_command tmux; then
        print_error "tmux is not installed"
        echo "  Install with: brew install tmux (macOS) or sudo apt-get install tmux (Linux)"
        ((errors++))
    else
        print_success "tmux is available ($(tmux -V))"
    fi
    
    # Check 2: hcom available
    if ! check_hcom; then
        print_error "hcom is not installed"
        echo "  Run ./install.sh to install hcom"
        ((errors++))
    else
        print_success "hcom is available"
    fi
    
    # Check 3: Terminal size
    local term_width=$(tput cols 2>/dev/null || echo 80)
    local term_height=$(tput lines 2>/dev/null || echo 24)
    
    if [[ $term_width -lt $MIN_TERMINAL_WIDTH ]]; then
        print_warning "Terminal width ($term_width) is less than recommended ($MIN_TERMINAL_WIDTH)"
        ((warnings++))
    else
        print_success "Terminal width is adequate ($term_width columns)"
    fi
    
    if [[ $term_height -lt $MIN_TERMINAL_HEIGHT ]]; then
        print_warning "Terminal height ($term_height) is less than recommended ($MIN_TERMINAL_HEIGHT)"
        ((warnings++))
    else
        print_success "Terminal height is adequate ($term_height rows)"
    fi
    
    # Check 4: PROJECT_ROOT exists
    if [[ ! -d "${PROJECT_ROOT:-}" ]]; then
        print_warning "PROJECT_ROOT not set or doesn't exist"
        ((warnings++))
    else
        print_success "Project root found ($PROJECT_ROOT)"
    fi
    
    # Check 5: Disk space (warn if less than 100MB free)
    local free_space=$(df -k "${SCRIPT_DIR}" 2>/dev/null | tail -1 | awk '{print $4}' || echo 0)
    if [[ $free_space -lt 102400 ]]; then
        print_warning "Low disk space (< 100MB free)"
        ((warnings++))
    else
        print_success "Disk space is adequate ($(($free_space / 1024))MB free)"
    fi
    
    # Check 6: No stale lock file
    if [[ -f "$SESSION_LOCK" ]]; then
        local lock_age=$(find "$SESSION_LOCK" -mmin +60 2>/dev/null | wc -l)
        if [[ $lock_age -gt 0 ]]; then
            print_warning "Removing stale lock file"
            rm -f "$SESSION_LOCK"
        else
            print_warning "Another dashboard instance may be starting"
            ((warnings++))
        fi
    fi
    
    # Summary
    echo ""
    if [[ $errors -gt 0 ]]; then
        print_error "Pre-flight checks failed with $errors error(s)"
        echo "  Please fix the errors above and try again."
        return 1
    elif [[ $warnings -gt 0 ]]; then
        print_warning "Pre-flight checks completed with $warnings warning(s)"
        echo "  Continuing despite warnings..."
    else
        print_success "Pre-flight checks passed"
    fi
    
    return 0
}

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
        
        # Health check: Verify session is responsive
        if ! tmux list-panes -t $SESSION -F "#{pane_id}" >/dev/null 2>&1; then
            print_warning "Session appears corrupted, recreating..."
            tmux kill-session -t $SESSION 2>/dev/null || true
            rm -f "$SESSION_LOCK"
            return 1
        fi
        
        # Show session info
        local pane_count=$(tmux list-panes -t $SESSION | wc -l)
        local window_count=$(tmux list-windows -t $SESSION | wc -l)
        print_success "Session is healthy with $pane_count pane(s) in $window_count window(s)"
        
        # Show agent status
        print_info "Active agents:"
        tmux list-panes -t $SESSION -F "  • #{pane_title} (#{pane_id})" 2>/dev/null || true
        
        attach
        exit 0
    fi
    return 1
}

# Session recovery - attempt to recover from crashed session
recover_session() {
    print_step "Attempting session recovery..."
    
    # Kill any orphaned sessions
    if tmux has-session -t $SESSION 2>/dev/null; then
        print_warning "Cleaning up orphaned session..."
        tmux kill-session -t $SESSION 2>/dev/null || true
    fi
    
    # Remove lock file
    rm -f "$SESSION_LOCK"
    
    # Clean up any orphaned agent processes
    pkill -f "agent-wrapper.sh.*hcom" 2>/dev/null || true
    
    print_success "Recovery complete"
    return 0
}

# Agent health check
check_agent_health() {
    local agent_name="$1"
    local pane_id="$2"
    
    # Check if pane exists and is running
    if ! tmux list-panes -t $SESSION -F "#{pane_id}" 2>/dev/null | grep -q "^$pane_id$"; then
        return 1
    fi
    
    # Check if pane title indicates error
    local pane_title=$(tmux display-message -p -t "$pane_id" "#{pane_title}" 2>/dev/null || echo "")
    if [[ "$pane_title" == *"error"* ]] || [[ "$pane_title" == *"failed"* ]]; then
        return 1
    fi
    
    return 0
}

# Start agent with health monitoring
start_agent_with_monitoring() {
    local pane_id="$1"
    local agent_name="$2"
    local cmd="$3"
    local title="$4"

    # Send the command    tmux send-keys -t "$pane_id" "export HCOM_NAME=$agent_name && $cmd" C-m
    
    # Set pane title
    tmux select-pane -t "$pane_id" -T "$title"
    
    # Schedule health check
    (
        sleep 5
        if ! check_agent_health "$agent_name" "$pane_id"; then
            print_warning "Agent $title may have failed to start"
        fi
    ) &
}

create_dashboard() {
    print_step "Creating Unified Command Center..."
    
    # Create lock file to prevent concurrent starts
    touch "$SESSION_LOCK"
    trap "rm -f $SESSION_LOCK" EXIT

    # Step 1: Initialize hcom daemon and relay worker
    # Resolve hcom path for use in tmux
    local hcom_bin=$(command -v hcom || echo "$HOME/.local/bin/hcom")
    if [ ! -x "$hcom_bin" ]; then
        hcom_bin="hcom"
    fi

    print_step "Initializing hcom services..."
    
    # Ensure hooks are installed for status tracking
    if ! $hcom_bin hooks status 2>/dev/null | grep -q "installed"; then
        print_info "Installing hcom hooks..."
        $hcom_bin hooks add all > /dev/null 2>&1 || print_warning "Failed to install hcom hooks"
    else
        print_success "hcom hooks are installed"
    fi

    # Start relay daemon if relay is enabled
    if $hcom_bin config relay_enabled --json 2>/dev/null | grep -q "true"; then
        print_info "Starting hcom relay daemon..."
        $hcom_bin relay daemon start > /dev/null 2>&1 || print_warning "Failed to start relay daemon"
    fi

    # Initialize Active Modules
    print_step "Initializing Active Modules..."
    while IFS= read -r module_id; do
        if [ -n "$module_id" ]; then
            local module_dir=$("$SCRIPT_DIR/module-manager.sh" dir "$module_id" 2>/dev/null)
            # Run any initialization scripts for the module if they exist
            if [[ -f "$module_dir/scripts/init.sh" ]]; then
                print_info "Initializing $module_id..."
                bash "$module_dir/scripts/init.sh" > /dev/null 2>&1 || print_warning "Initialization for $module_id failed"
            fi
            
            # Module-specific legacy hooks (e.g., atari constants)
            if [[ "$module_id" == "atari-8bit" ]]; then
                [ -f "$module_dir/scripts/init-atari-constants.sh" ] && bash "$module_dir/scripts/init-atari-constants.sh" > /dev/null 2>&1
                [ -f "$module_dir/scripts/hcom-atari-sync.sh" ] && bash "$module_dir/scripts/hcom-atari-sync.sh" > /dev/null 2>&1
            fi
        fi
    done < <(bash "$SCRIPT_DIR/module-manager.sh" active 2>/dev/null)

    sleep 1

    # Step 2: Create session with hcom TUI
    print_step "Creating tmux session..."
    if ! tmux new-session -d -s $SESSION -n "dashboard" "$hcom_bin" 2>&1; then
        print_error "Failed to create tmux session"
        rm -f "$SESSION_LOCK"
        return 1
    fi

    if ! tmux has-session -t $SESSION 2>/dev/null; then
        print_error "Session creation failed"
        rm -f "$SESSION_LOCK"
        return 1
    fi
    
    print_success "Session created successfully"

    # Configure tmux
    tmux set-option -g mouse on
    tmux set-option -g pane-border-status top
    tmux set-option -g pane-border-format "#P: #{pane_title}"
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
        # Split and capture the newly created pane ID
        tmux split-window -v -t "$SESSION:dashboard.0" -l 5 -c "$PWD"
        console_id=$(tmux display-message -p "#{pane_id}")
    fi

    # 4b. Create Right Column
    # Split Pane 0 (HCOM) horizontally to create Right Column
    tmux split-window -h -t "$SESSION:dashboard.0" -c "$PWD"
    local right_col_id=$(tmux display-message -p "#{pane_id}")

    # 4c. Split Right Column for components
    local agent_pane_ids=("$right_col_id")
    if [ $num_right_panes -gt 1 ]; then
        local current_pane_id="$right_col_id"
        for ((i=1; i<num_right_panes; i++)); do
            tmux split-window -v -t "$current_pane_id" -c "$PWD"
            current_pane_id=$(tmux display-message -p "#{pane_id}")
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
        
        # Send hcom initialization commands with proper error handling
        tmux send-keys -t "$console_id" "export HCOM_NAME=$user_name" C-m
        tmux send-keys -t "$console_id" "sleep 1" C-m
        # Register user with hcom without blocking the shell
        tmux send-keys -t "$console_id" "if command -v hcom >/dev/null 2>&1; then hcom status --name \$HCOM_NAME >/dev/null 2>&1; else echo 'hcom not found, please run ./install.sh'; fi" C-m
        tmux send-keys -t "$console_id" "sleep 2" C-m
        tmux send-keys -t "$console_id" "alias s='hcom send --name \$HCOM_NAME @conductor -- \"!status\"'" C-m
        tmux send-keys -t "$console_id" "alias t='hcom send --name \$HCOM_NAME @conductor -- \"!test\"'" C-m
        tmux send-keys -t "$console_id" "alias b='hcom send --name \$HCOM_NAME @conductor -- \"!build\"'" C-m
        tmux send-keys -t "$console_id" "clear" C-m
        tmux send-keys -t "$console_id" "echo -e \"${BLUE}╔══════════════════════════════════════════════╗${NC}\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"${BLUE}║           ai-colab HCOM User Console         ║${NC}\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"${BLUE}╚══════════════════════════════════════════════╝${NC}\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"Logged in as: ${GREEN}$user_name${NC}\"" C-m
        tmux send-keys -t "$console_id" "echo -e \\\"\\\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"${YELLOW}Available Conductor Commands:${NC}\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"  ${GREEN}s${NC} (!status)      - Get project health & progress\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"  ${GREEN}t${NC} (!test)        - Run all automated tests\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"  ${GREEN}b${NC} (!build)       - Build project and integrated apps\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"  !kb <query>      - Search architectural knowledge base\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"  !git-sync        - Pull latest changes from remote\"" C-m

        # Dynamically list module-specific commands
        while IFS= read -r module_id; do
            if [ -n "$module_id" ]; then
                local mod_name=$(bash "$SCRIPT_DIR/module-manager.sh" info "$module_id" 2>/dev/null | grep "^name=" | cut -d'=' -f2)
                tmux send-keys -t "$console_id" "echo -e \"${YELLOW}${mod_name} Commands:${NC}\"" C-m
                bash "$SCRIPT_DIR/module-manager.sh" commands --raw "$module_id" 2>/dev/null | while IFS='|' read -r trigger script; do
                    if [ -n "$trigger" ]; then
                        # Clean up script path for display (relative to project root)
                        local display_script=${script#$PROJECT_ROOT/}
                        tmux send-keys -t "$console_id" "echo -e \"  ${GREEN}${trigger}${NC} - Module task\"" C-m
                    fi
                done
            fi
        done < <(bash "$SCRIPT_DIR/module-manager.sh" active 2>/dev/null)

        tmux send-keys -t "$console_id" "echo -e \"  !help            - Show all available commands\"" C-m
        tmux send-keys -t "$console_id" "echo \\\"\\\"" C-m
        tmux send-keys -t "$console_id" "echo -e \"${GREEN}HCOM Status:\${NC} \$(hcom status --name \$HCOM_NAME 2>&1 | head -1 || echo 'Not connected')\"" C-m

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
        print_step "Starting Google Chat bridge..."
        tmux new-window -d -t $SESSION -n "bridge" "bash $SCRIPT_DIR/hcom-chat-bridge.sh"
    fi

    print_success "Unified Command Center Online"
    
    # Final status summary
    echo ""
    echo -e "${GREEN}+======================================================+${NC}"
    echo -e "${GREEN}|              Dashboard Ready!                        |${NC}"
    echo -e "${GREEN}+======================================================+${NC}"
    echo ""
    
    local final_pane_count=$(tmux list-panes -t $SESSION | wc -l)
    local final_window_count=$(tmux list-windows -t $SESSION | wc -l)
    
    echo -e "${BLUE}Session Summary:${NC}"
    echo "  • Panes: $final_pane_count"
    echo "  • Windows: $final_window_count"
    echo "  • Session: $SESSION"
    echo ""
    echo -e "${BLUE}Navigation:${NC}"
    echo "  • Ctrl+b Arrow Keys - Move between panes"
    echo "  • Ctrl+b z - Zoom current pane"
    echo "  • Ctrl+b d - Detach from session"
    echo "  • Ctrl+b ? - Show all tmux shortcuts"
    echo ""
    
    sleep 1
}

attach() {
    print_info "Attaching in 1s..."
    sleep 1
    echo ""
    echo -e "${CYAN}+======================================================+${NC}"
    echo -e "${CYAN}|  Dashboard Navigation Guide                          |${NC}"
    echo -e "${CYAN}+======================================================+${NC}"
    echo "  Ctrl+b ->/<-/Up/Down : Navigate between panes"
    echo "  Ctrl+b z        : Zoom/unzoom current pane"
    echo "  Ctrl+b d        : Detach (keep running)"
    echo "  Ctrl+b %        : Split vertically"
    echo "  Ctrl+b \"       : Split horizontally"
    echo "  Ctrl+b c        : Create new window"
    echo "  Ctrl+b n/p      : Next/previous window"
    echo "  Ctrl+b l        : Last window"
    echo "  Ctrl+b ?        : Show all shortcuts"
    echo -e "${CYAN}+======================================================+${NC}"
    echo ""
    tmux attach -t $SESSION
}

main() {
    echo ""
    echo -e "${BLUE}+======================================================+${NC}"
    echo -e "${BLUE}|       HCOM Command Center v2.4 (Enhanced)           |${NC}"
    echo -e "${BLUE}+======================================================+${NC}"
    echo ""

    # Run pre-flight checks first
    if ! preflight_checks; then
        echo ""
        print_error "Dashboard launch aborted due to pre-flight failures"
        exit 1
    fi
    
    echo ""

    # Defaults
    WITH_QWEN=true
    WITH_GEMINI=true
    WITH_VLLM=false  # vLLM is opt-in only
    WITH_DEEPSEEK=false
    WITH_CLAUDE=false
    WITH_NEMO=false
    WITH_NEMOCLAW=false
    WITH_CONDUCTOR=true   # Conductor is now recommended for project management
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
    
    # Reconnect to existing session if possible. If not, create a new one.
    # Note: reconnect will 'exit 0' if it successfully attaches.
    reconnect || create_dashboard
    
    attach
}

main "$@"
