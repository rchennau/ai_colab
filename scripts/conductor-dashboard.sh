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

render_modular_sections() {
    local sections_json=$(python3 "$SCRIPT_DIR/module-manager.py" sections "$PROJECT_ROOT")
    
    # Simple extraction of sections from JSON list
    echo "$sections_json" | grep -oP '\{"name": "[^"]+", "type": "[^"]+", "source": "[^"]+"\}' | while read -r section; do
        local name=$(echo "$section" | grep -oP '"name": "\K[^"]+')
        local stype=$(echo "$section" | grep -oP '"type": "\K[^"]+')
        local source=$(echo "$section" | grep -oP '"source": "\K[^"]+')
        
        echo -e "\n${YELLOW}--- $name ---${NC}"
        if [[ "$stype" == "sql" ]]; then
            if has_command sqlite3; then
                sqlite3 "$DB_PATH" "$source" | while read -r line; do
                    echo "  $line"
                done
            else
                echo "  (SQLite not available)"
            fi
        elif [[ "$stype" == "file" ]]; then
            if [[ -f "$PROJECT_ROOT/$source" ]]; then
                head -n 5 "$PROJECT_ROOT/$source" | while read -r line; do
                    echo "  $line"
                done
            else
                echo "  (Source file not found: $source)"
            fi
        fi
    done
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
render_modular_sections
render_events
render_footer
