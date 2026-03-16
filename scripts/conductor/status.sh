#!/bin/bash
# Global Conductor Status Monitor
# Works with any project - auto-detects or uses specified project

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Auto-detect project
detect_project() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [ -f "$dir/conductor/tracks.md" ] || [ -f "$dir/conductor/product.md" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

PROJECT_DIR=$(detect_project 2>/dev/null) || PROJECT_DIR=""

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Conductor Status Monitor            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# HCOM status
echo -e "${YELLOW}HCOM Status:${NC}"
hcom status 2>&1 | grep -E "(agents|terminal)" || echo "  hcom not running"
echo ""

# List conductor agents
echo -e "${YELLOW}Conductor Agents:${NC}"
hcom list 2>&1 | grep -E "conductor" || echo "  No conductor agents running"
echo ""

# Project status
if [ -n "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/conductor/tracks.md" ]; then
    echo -e "${YELLOW}Project: ${GREEN}$PROJECT_DIR${NC}"
    TRACKS_TIME=$(stat -c %y "$PROJECT_DIR/conductor/tracks.md" 2>/dev/null | cut -d'.' -f1)
    echo -e "  Tracks updated: ${GREEN}$TRACKS_TIME${NC}"
    
    TOTAL=$(grep -c "^\- \[.\] \*\*Track:" "$PROJECT_DIR/conductor/tracks.md" 2>/dev/null || echo "0")
    COMPLETE=$(grep -c "^\- \[x\] \*\*Track:" "$PROJECT_DIR/conductor/tracks.md" 2>/dev/null || echo "0")
    PLANNING=$(grep -c "^\- \[ \] \*\*Track:" "$PROJECT_DIR/conductor/tracks.md" 2>/dev/null || echo "0")
    
    echo -e "  Tracks: ${GREEN}$COMPLETE complete${NC}, ${YELLOW}$PLANNING planning${NC}, ${BLUE}$TOTAL total${NC}"
else
    echo -e "${YELLOW}Project: ${RED}Not in a project directory${NC}"
    echo -e "  ${YELLOW}Use -p /path/to project or cd to project${NC}"
fi
echo ""

echo -e "${YELLOW}Recent Events:${NC}"
hcom events 2>&1 | tail -5 | while read line; do
    echo "  $line"
done || echo "  No events"
echo ""

echo -e "${GREEN}Status check complete${NC}"
