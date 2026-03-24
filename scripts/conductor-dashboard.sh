#!/usr/bin/env bash
# Conductor Dashboard v3.0 (TUI)
# Renders a high-density project summary for the Conductor terminal pane.

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

PROJECT_ROOT=$(detect_project_root)
DB_PATH=$(get_hcom_db_path)

# Colors
CYAN='\033[0;36m'
WHITE='\033[1;37m'

render_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}               ai-colab Conductor Dashboard v3.0              ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

render_progress() {
    local progress=$(blackboard_get "project_progress" || echo "0%")
    local active_track=$(blackboard_get "active_track" || echo "None")
    
    echo -e "${CYAN}Progress: ${WHITE}$progress${NC} | ${CYAN}Active Track: ${WHITE}$active_track${NC}"
}

render_performance() {
    [[ "${ENABLE_ATARI_LX:-false}" == "false" ]] && return
    echo -e "\n${YELLOW}--- Latest Performance ---${NC}"
    # Fetch last 3 routines
...
}

render_memory() {
    [[ "${ENABLE_ATARI_LX:-false}" == "false" ]] && return
    echo -e "\n${GREEN}--- Memory Allocation ---${NC}"
    local map_file="$PROJECT_ROOT/conductor/reports/memory_map.txt"
...
}

render_events() {
    echo -e "\n${BLUE}--- Recent Events ---${NC}"
    hcom events --last 3 --all --type message | while read -r line; do
        local from=$(extract_json_value "$line" "msg_from")
        local text=$(extract_json_value "$line" "msg_text")
        # Truncate text
        text=$(echo "$text" | cut -c1-50)
        echo -e "  [${GREEN}$from${NC}] $text"
    done
}

render_footer() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "Agent: ${GREEN}$HCOM_NAME${NC} | Listening for commands..."
}

# Main render loop
render_header
render_progress
render_performance
render_memory
render_events
render_footer
