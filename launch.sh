#!/usr/bin/env bash
# ai-colab Unified Launcher
# Launches the multi-agent dashboard, conductor, and selected agents.

set -e

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/scripts/utils.sh" ]; then
    source "$SCRIPT_DIR/scripts/utils.sh"
else
    # Fallback colors if utils not found
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
    has_command() { command -v "$1" >/dev/null 2>&1; }
fi

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       ai-colab Unified Launcher       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check for hcom
if ! has_command hcom; then
    echo -e "${RED}Error: hcom is not installed.${NC}"
    echo -e "Please run ./install.sh first."
    exit 1
fi

# Check for tmux
if ! has_command tmux; then
    echo -e "${RED}Error: tmux is not installed.${NC}"
    echo -e "Please run ./install.sh first."
    exit 1
fi

# 1. Project Detection
PROJECT_ROOT=$(detect_project_root 2>/dev/null || echo "$SCRIPT_DIR")
echo -e "${GREEN}Project Root:${NC} $PROJECT_ROOT"

# 2. Interactive Selection
echo -e "\n${BLUE}Select components to launch:${NC}"
echo "1) Dashboard (hcom TUI + Agents)"
echo "2) Conductor (Project Manager)"
echo "3) Both (Recommended)"
echo ""
read -p "Choice [1-3, default 3]: " LAUNCH_CHOICE
LAUNCH_CHOICE=${LAUNCH_CHOICE:-3}

DASHBOARD=false
CONDUCTOR=false

case "$LAUNCH_CHOICE" in
    1) DASHBOARD=true ;;
    2) CONDUCTOR=true ;;
    3) DASHBOARD=true; CONDUCTOR=true ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

# 3. Agent Selection (if dashboard)
DASHBOARD_FLAGS=""
if [ "$DASHBOARD" = true ]; then
    echo -e "\n${BLUE}Select agents for the Dashboard:${NC}"
    read -p "Include Qwen? [Y/n]: " -n 1 -r; echo ""; [[ $REPLY =~ ^[Nn]$ ]] && DASHBOARD_FLAGS+=" --no-qwen"
    read -p "Include Gemini? [Y/n]: " -n 1 -r; echo ""; [[ $REPLY =~ ^[Nn]$ ]] && DASHBOARD_FLAGS+=" --no-gemini"
    read -p "Include Atari vLLM? [Y/n]: " -n 1 -r; echo ""; [[ $REPLY =~ ^[Nn]$ ]] && DASHBOARD_FLAGS+=" --no-vllm"
    read -p "Include Claude? [y/N]: " -n 1 -r; echo ""; [[ $REPLY =~ ^[Yy]$ ]] && DASHBOARD_FLAGS+=" --add-claude"
    read -p "Include DeepSeek? [y/N]: " -n 1 -r; echo ""; [[ $REPLY =~ ^[Yy]$ ]] && DASHBOARD_FLAGS+=" --add-deepseek"
    read -p "Include NeMo? [y/N]: " -n 1 -r; echo ""; [[ $REPLY =~ ^[Yy]$ ]] && DASHBOARD_FLAGS+=" --add-nemo"
    
    if [ "$CONDUCTOR" = true ]; then
        DASHBOARD_FLAGS+=" --conductor"
    fi
fi

# 4. Launching
if [ "$DASHBOARD" = true ]; then
    echo -e "\n${GREEN}Launching Unified Dashboard...${NC}"
    # Change to project root to ensure dashboard detects it
    cd "$PROJECT_ROOT"
    exec bash "$SCRIPT_DIR/scripts/dashboard-launch.sh" $DASHBOARD_FLAGS
elif [ "$CONDUCTOR" = true ]; then
    echo -e "\n${GREEN}Launching Conductor Agent...${NC}"
    cd "$PROJECT_ROOT"
    # Use the global conductor command if installed, otherwise use the script
    if has_command conductor; then
        exec conductor
    else
        exec bash "$SCRIPT_DIR/scripts/conductor/launch.sh"
    fi
fi
