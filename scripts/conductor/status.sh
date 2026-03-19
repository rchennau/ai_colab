#!/usr/bin/env bash
# Global Conductor Status Monitor
# Works with any project - auto-detects or uses specified project

set -e

# Find script directory and source utils
# Note: status.sh is in scripts/conductor/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils.sh"

# Auto-detect project
PROJECT_DIR=$(detect_project_root 2>/dev/null) || PROJECT_DIR=""

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Conductor Status Monitor            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# HCOM status
echo -e "${YELLOW}HCOM Status:${NC}"
if check_hcom; then
    hcom status 2>&1 | grep -E "(agents|terminal)" || echo "  hcom not running"
fi
echo ""

# List conductor agents
echo -e "${YELLOW}Conductor Agents:${NC}"
if has_command hcom; then
    hcom list 2>&1 | grep -E "conductor" || echo "  No conductor agents running"
fi
echo ""

# Project status
if [ -n "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/conductor/tracks.md" ]; then
    echo -e "${YELLOW}Project: ${GREEN}$PROJECT_DIR${NC}"
    TRACKS_TIME=$(get_file_mtime "$PROJECT_DIR/conductor/tracks.md")
    echo -e "  Tracks updated: ${GREEN}$TRACKS_TIME${NC}"
    
    TOTAL=$(grep -c "^\- \[.\] \*\*Track:" "$PROJECT_DIR/conductor/tracks.md" 2>/dev/null || echo "0")
    COMPLETE=$(grep -c "^\- \[x\] \*\*Track:" "$PROJECT_DIR/conductor/tracks.md" 2>/dev/null || echo "0")
    PLANNING=$(grep -c "^\- \[ \] \*\*Track:" "$PROJECT_DIR/conductor/tracks.md" 2>/dev/null || echo "0")
    
    echo -e "  Tracks: ${GREEN}$COMPLETE complete${NC}, ${YELLOW}$PLANNING planning${NC}, ${BLUE}$TOTAL total${NC}"
else
    echo -e "${YELLOW}Project: ${RED}Not in a project directory or tracks.md missing${NC}"
    echo -e "  ${YELLOW}Use -p /path/to project or cd to project${NC}"
fi
echo ""

echo -e "${YELLOW}Recent Events:${NC}"
if has_command hcom; then
    hcom events 2>&1 | tail -5 | while read line; do
        echo "  $line"
    done || echo "  No events"
else
    echo "  hcom not available"
fi
echo ""

echo -e "${GREEN}Status check complete${NC}"
