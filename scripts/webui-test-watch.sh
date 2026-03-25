#!/usr/bin/env bash
# Web UI Automated Test Watcher Launcher
# Starts the file watcher for automated testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WATCHER_SCRIPT="$SCRIPT_DIR/webui-test-watcher.py"
VENV_DIR="$PROJECT_ROOT/webui-venv"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Web UI Automated Test Watcher                       ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check if watchdog is installed
check_dependencies() {
    echo -e "${CYAN}▶ Checking dependencies...${NC}"
    
    if [[ -d "$VENV_DIR" ]]; then
        source "$VENV_DIR/bin/activate"
        echo -e "${GREEN}✓ Using virtual environment${NC}"
    fi
    
    if ! python3 -c "import watchdog" 2>/dev/null; then
        echo -e "${YELLOW}⚠ watchdog not installed, installing...${NC}"
        if [[ -d "$VENV_DIR" ]]; then
            pip install -q watchdog
        else
            pip3 install --user watchdog
        fi
    fi
    
    echo -e "${GREEN}✓ Dependencies OK${NC}"
    echo ""
}

# Check if watcher script exists
if [[ ! -f "$WATCHER_SCRIPT" ]]; then
    echo -e "${RED}✗ Watcher script not found: $WATCHER_SCRIPT${NC}"
    exit 1
fi

print_header
check_dependencies

echo -e "${GREEN}Starting file watcher...${NC}"
echo -e "${CYAN}Monitoring:${NC} webui/, tests/test_webui.sh, requirements-webui.txt"
echo -e "${CYAN}Tests will run automatically when changes are detected${NC}"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Run watcher
python3 "$WATCHER_SCRIPT"
