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
            local init_script=$("$SCRIPT_DIR/module-manager.sh" init "$module_id" 2>/dev/null)
            if [[ -n "$init_script" && -f "$PROJECT_ROOT/$init_script" ]]; then
                print_info "Initializing $module_id..."
                bash "$PROJECT_ROOT/$init_script" > /dev/null 2>&1 || print_warning "Initialization for $module_id failed"
            fi
        fi
    done < <(bash "$SCRIPT_DIR/module-manager.sh" active 2>/dev/null)

    sleep 1

    # Step 2: Create session with hcom TUI
    print_step "Creating tmux session..."

    # Use ai-colab's local tmux config to ensure consistent behavior
    # This prevents conflicts with user's ~/.tmux.conf and ensures
    # ai-colab is fully self-contained and portable.
    local tmux_conf_file=""
    local ai_colab_conf="$PROJECT_ROOT/.ai-colab/tmux.conf"

    if [[ -f "$ai_colab_conf" ]]; then
        tmux_conf_file="$ai_colab_conf"
        print_info "Using ai-colab tmux config: $tmux_conf_file"
    else
        # Fallback: create minimal inline config
        tmux_conf_file="/tmp/ai-colab-tmux-$$.conf"
        cat > "$tmux_conf_file" << 'TMUX_CONF'
set -g mouse on
set -g pane-border-status top
set -g pane-border-format "#P: #{pane_title}"
set -g allow-rename off
TMUX_CONF
        print_info "Created temporary tmux config: $tmux_conf_file"
    fi

    # Start tmux with our config to avoid user config conflicts
    if ! tmux -f "$tmux_conf_file" new-session -d -s "$SESSION" -n "dashboard" "$hcom_bin" 2>&1; then
        print_error "Failed to create tmux session"
        rm -f "$SESSION_LOCK"
        [[ -f "$tmux_conf_file" && "$tmux_conf_file" == /tmp/* ]] && rm -f "$tmux_conf_file"
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
    
    # Custom Bindings for UX Revolution
    tmux bind-key f resize-pane -Z
    tmux bind-key h select-window -t :0  # Quick return to dashboard
    tmux bind-key l select-window -t :1  # Quick jump to fleet

    # Verbose Toggle (P6.4) - Ctrl+b v to switch between compact/verbose mode
    tmux bind-key v run-shell "bash '$SCRIPT_DIR/verbose-toggle.sh' toggle"
    
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

    # Step 4: Dynamic Layout Creation (P17.1)
    # Determine layout based on agent count
    local layout_name
    layout_name=$(tmux_get_layout_name "$num_right_panes")
    local layout_desc
    layout_desc=$(tmux_get_layout_description "$layout_name")
    print_info "Selected layout: $layout_name — $layout_desc ($num_right_panes agents)"

    # Apply layout-specific pane creation
    tmux_apply_layout "$layout_name" "$SESSION" "$PROJECT_ROOT" "$num_right_panes" right_panes

    # Capture all pane IDs from the session (skip HCOM pane 0)
    local agent_pane_ids=()
    while IFS= read -r pane_id; do
        agent_pane_ids+=("$pane_id")
    done < <(tmux list-panes -t "$SESSION:dashboard" -F "#{pane_id}" | tail -n +2)

    # Capture console pane ID (last pane in dashboard window)
    local console_id=""
    if [ "${WITH_CONSOLE:-true}" == "true" ]; then
        console_id=$(tmux list-panes -t "$SESSION:dashboard" -F "#{pane_id}" | tail -1)
    fi

    print_info "Layout creation complete. Agent panes: ${#agent_pane_ids[@]}"

    # Step 5: Launch Console
    if [ -n "$console_id" ]; then
        local user_name="user_$(whoami)"
        print_info "Initializing Enhanced Console in pane..."

        # Use the new python console
        tmux send-keys -t "$console_id" "python3 '$SCRIPT_DIR/console.py' --name '$user_name'" C-m

        tmux set-option -t "$console_id" -p @agent_name "CONSOLE"
        tmux select-pane -t "$console_id" -T "User Console ($user_name)"
    fi

    # Step 6: Launch Agent Components
    for i in "${!right_panes[@]}"; do
        local component="${right_panes[$i]}"
        local pane_id="${agent_pane_ids[$i]}"
        local pane_idx=$(tmux display-message -p -t "$pane_id" "#{pane_index}")
        local agent_name=""
        local title=""

        # Determine agent name and title
        case $component in
            conductor) agent_name="conductor_dev"; title="Conductor" ;;
            qwen)      agent_name="qwen_dev";      title="Qwen" ;;
            gemini)    agent_name="gemini_dev";    title="Gemini" ;;
            vllm)      agent_name="vllm_dev";      title="vLLM" ;;
            deepseek)  agent_name="deepseek_dev";  title="DeepSeek" ;;
            claude)    agent_name="claude_dev";    title="Claude" ;;
            nemo)      agent_name="nemo_dev";      title="NeMo" ;;
            nemoclaw)  agent_name="nemoclaw";      title="nemoclaw" ;;
            *)         agent_name="${component}_dev"; title="$component" ;;
        esac

        print_info "Launching $title in pane $pane_idx..."

        # Source ai-colab environment for clean, self-contained execution
        # This ensures agents run in a consistent environment regardless
        # of user's shell configuration.
        local env_cmd="source '$SCRIPT_DIR/ai-colab-env.sh' 2>/dev/null || true"
        tmux send-keys -t "$pane_id" "$env_cmd" C-m
        sleep 0.3

        # Export HCOM_NAME for the wrapper
        tmux send-keys -t "$pane_id" "export HCOM_NAME=\"$agent_name\"" C-m
        sleep 0.3

        # Launch using agent-wrapper.sh (Standardized)
        local wrapper_cmd="bash '$SCRIPT_DIR/agent-wrapper.sh' '$component' --name '$agent_name'"
        
        # Add conductor-specific context flags if they exist (legacy support)
        if [[ "$component" == "qwen" && -n "${QWEN_CONTEXT_FILE:-}" ]]; then
            export QWEN_CONTEXT_FILE
        elif [[ "$component" == "gemini" && -n "${GEMINI_CONTEXT_FILE:-}" ]]; then
            export GEMINI_CONTEXT_FILE
        fi

        tmux send-keys -t "$pane_id" "$wrapper_cmd" C-m

        # Set pane metadata and title
        tmux set-option -t "$pane_id" -p @agent_name "$(tr '[:lower:]' '[:upper:]' <<< ${title})"
        tmux select-pane -t "$pane_id" -T "$title"
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

    # Step 7.5: Focus Mode & Status Bar Integration (P17.2)
    # Configure pane border format to show agent status
    tmux set-option -g pane-border-status top
    tmux set-option -g pane-border-format "#P: #{pane_title}"

    # Generate and display fleet status bar
    local fleet_status
    fleet_status=$(tmux_generate_status_bar)
    print_info "Fleet Status: $fleet_status"

    # Set up focus mode key bindings
    # Ctrl+b f - Toggle focus mode (zoom/unzoom current pane)
    tmux bind-key f run-shell "tmux resize-pane -Z; tmux set-option -g pane-border-format '#P: #{pane_title}'"

    # Ctrl+b 1-9 - Quick switch to pane by index
    for i in {1..9}; do
        tmux bind-key "$i" select-pane -t "$i"
    done

    # Step 7.6: Start Real-Time Status Bar Updater (P17.4)
    # Launch background process to update tmux status line every 20s
    bash "$SCRIPT_DIR/update-status-bar.sh" "$SESSION" &
    STATUS_BAR_PID=$!
    print_info "Started status bar updater (PID: $STATUS_BAR_PID)"

    # Step 7.7: Save Layout for Session Persistence (P17.5)
    tmux_save_layout "$SESSION" "default"
    print_info "Layout saved as 'default' preset"

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
    echo "  • Ctrl+b f - Focus mode (toggle zoom on current pane)"
    echo "  • Ctrl+b 1-9 - Quick switch to pane by index"
    echo "  • Ctrl+b d - Detach from session"
    echo "  • Ctrl+b ? - Show all tmux shortcuts"
    echo ""
    echo -e "${BLUE}Focus Mode:${NC}"
    echo "  • Press Ctrl+b f to focus on current agent pane"
    echo "  • Fleet status bar remains visible at all times"
    echo "  • Press Ctrl+b 1-9 to switch focus between agents"
    echo "  • Press Ctrl+b z or Ctrl+b f again to return to fleet view"
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
    echo "  Ctrl+b f        : Focus mode (toggle zoom)"
    echo "  Ctrl+b 1-9      : Quick switch to pane by index"
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

# Session Configuration Persistence
SESSION_CONFIG_KEY="dashboard_session_config"

save_session_config() {
    local config="WITH_QWEN=$WITH_QWEN|WITH_GEMINI=$WITH_GEMINI|WITH_VLLM=$WITH_VLLM|WITH_DEEPSEEK=$WITH_DEEPSEEK|WITH_CLAUDE=$WITH_CLAUDE|WITH_NEMO=$WITH_NEMO|WITH_NEMOCLAW=$WITH_NEMOCLAW|WITH_CONDUCTOR=$WITH_CONDUCTOR|WITH_BRIDGE=$WITH_BRIDGE|WITH_CONSOLE=$WITH_CONSOLE"
    blackboard_set "$SESSION_CONFIG_KEY" "$config"
    print_info "Session configuration saved to blackboard"
}

load_session_config() {
    local config=$(blackboard_get "$SESSION_CONFIG_KEY")
    if [[ -n "$config" && "$config" != "None" ]]; then
        print_info "Loading last active session configuration..."
        IFS='|' read -ra parts <<< "$config"
        for part in "${parts[@]}"; do
            eval "export $part"
        done
        return 0
    fi
    return 1
}

# ============================================================
# Dynamic tmux Layouts (P17.1)
# ============================================================

# Get layout name based on agent count
# Usage: tmux_get_layout_name <agent_count>
# Returns: layout name (side-by-side, grid, tabbed, compact)
tmux_get_layout_name() {
    local agent_count="${1:-0}"

    if [[ $agent_count -le 2 ]]; then
        echo "side-by-side"
    elif [[ $agent_count -le 4 ]]; then
        echo "grid"
    elif [[ $agent_count -le 7 ]]; then
        echo "tabbed"
    else
        echo "compact"
    fi
}

# Get human-readable description for a layout
# Usage: tmux_get_layout_description <layout_name>
# Returns: description string
tmux_get_layout_description() {
    local layout_name="$1"

    case "$layout_name" in
        side-by-side)
            echo "HCOM left, agents side-by-side on right"
            ;;
        grid)
            echo "HCOM left, agents in 2x2 grid on right"
            ;;
        tabbed)
            echo "HCOM left, agents in tabbed windows by team"
            ;;
        compact)
            echo "HCOM left, agents in compact vertical list"
            ;;
        *)
            echo "Unknown layout: $layout_name"
            ;;
    esac
}

# Apply a specific layout to the tmux session
# Usage: tmux_apply_layout <layout_name> <session> <project_root> <agent_count> <agents_array_name>
tmux_apply_layout() {
    local layout_name="$1"
    local session="$2"
    local project_root="$3"
    local agent_count="$4"
    local -n agents_ref=$5

    case "$layout_name" in
        side-by-side)
            # 2 agents or fewer: HCOM left, agents side-by-side on right
            tmux split-window -h -t "$session:dashboard.0" -c "$project_root"
            local right_col_id=$(tmux display-message -p "#{pane_id}")
            print_info "Created right column pane: $right_col_id"

            # Split right column for second agent if needed
            if [[ $agent_count -gt 1 ]]; then
                tmux split-window -v -t "$right_col_id" -c "$project_root"
                tmux select-layout -t "$session:dashboard" tiled >/dev/null 2>&1 || true
            fi

            # Console at bottom
            if [ "${WITH_CONSOLE:-true}" == "true" ]; then
                tmux split-window -v -t "$session:dashboard.0" -l 8 -c "$project_root"
                tmux resize-pane -t "$session:dashboard" -y 8 2>/dev/null || true
            fi

            tmux resize-pane -t "$session:dashboard.0" -x 85
            ;;

        grid)
            # 3-4 agents: HCOM left, agents in 2x2 grid on right
            tmux split-window -h -t "$session:dashboard.0" -c "$project_root"
            local right_col_id=$(tmux display-message -p "#{pane_id}")
            print_info "Created right column pane: $right_col_id"

            # Split right column into grid
            local current_pane_id="$right_col_id"
            for ((i=1; i<agent_count; i++)); do
                tmux split-window -v -t "$current_pane_id" -c "$project_root"
                current_pane_id=$(tmux display-message -p "#{pane_id}")
                tmux select-layout -t "$session:dashboard" tiled >/dev/null 2>&1 || true
            done

            # Console at bottom
            if [ "${WITH_CONSOLE:-true}" == "true" ]; then
                tmux split-window -v -t "$session:dashboard.0" -l 8 -c "$project_root"
            fi

            tmux resize-pane -t "$session:dashboard.0" -x 85
            ;;

        tabbed)
            # 5-7 agents: HCOM left, agents in tabbed windows by team
            tmux split-window -h -t "$session:dashboard.0" -c "$project_root"
            local right_col_id=$(tmux display-message -p "#{pane_id}")

            # Split right column vertically for primary agents
            local current_pane_id="$right_col_id"
            local primary_count=4
            if [[ $agent_count -lt $primary_count ]]; then
                primary_count=$agent_count
            fi

            for ((i=1; i<primary_count; i++)); do
                tmux split-window -v -t "$current_pane_id" -c "$project_root"
                current_pane_id=$(tmux display-message -p "#{pane_id}")
                tmux select-layout -t "$session:dashboard" tiled >/dev/null 2>&1 || true
            done

            # Create fleet window for overflow agents
            if [[ $agent_count -gt $primary_count ]]; then
                tmux new-window -t "$session" -n "fleet" -c "$project_root"
                local fleet_pane_id=$(tmux display-message -p "#{pane_id}")
                local overflow_count=$((agent_count - primary_count))
                for ((i=1; i<overflow_count; i++)); do
                    tmux split-window -v -t "$fleet_pane_id" -c "$project_root"
                    fleet_pane_id=$(tmux display-message -p "#{pane_id}")
                    tmux select-layout -t "$session:fleet" tiled >/dev/null 2>&1 || true
                done
            fi

            # Console at bottom
            if [ "${WITH_CONSOLE:-true}" == "true" ]; then
                tmux split-window -v -t "$session:dashboard.0" -l 8 -c "$project_root"
            fi

            tmux resize-pane -t "$session:dashboard.0" -x 85
            ;;

        compact)
            # 8+ agents: HCOM left, agents in compact vertical list
            tmux split-window -h -t "$session:dashboard.0" -c "$project_root"
            local right_col_id=$(tmux display-message -p "#{pane_id}")

            # Split right column into compact vertical list
            local current_pane_id="$right_col_id"
            for ((i=1; i<agent_count; i++)); do
                tmux split-window -v -t "$current_pane_id" -c "$project_root"
                current_pane_id=$(tmux display-message -p "#{pane_id}")
                tmux select-layout -t "$session:dashboard" tiled >/dev/null 2>&1 || true
            done

            # Console at bottom
            if [ "${WITH_CONSOLE:-true}" == "true" ]; then
                tmux split-window -v -t "$session:dashboard.0" -l 6 -c "$project_root"
            fi

            tmux resize-pane -t "$session:dashboard.0" -x 90
            ;;
    esac
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

    # Try to load saved config if no arguments provided
    if [[ $# -eq 0 ]]; then
        load_session_config || true
    fi

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

    # Save current config for next time
    save_session_config

    check_prereqs
    
    # Reconnect to existing session if possible. If not, create a new one.
    # Note: reconnect will 'exit 0' if it successfully attaches.
    reconnect || create_dashboard
    
    attach
}

main "$@"
