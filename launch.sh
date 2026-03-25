#!/usr/bin/env bash
# ai-colab Unified Launcher
# Launches the multi-agent dashboard, conductor, and selected agents.
# Now with terminal-specific optimizations for iTerm2, WSL, and more.

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

# Source terminal detection and apply optimizations
if [ -f "$SCRIPT_DIR/scripts/terminal-detect.sh" ]; then
    source "$SCRIPT_DIR/scripts/terminal-detect.sh"
    init_terminal
fi

clear
ui_banner "ai-colab Unified Launcher" "${BLUE}"
echo ""

# Display terminal info if detected
if [[ -n "$AI_COLAB_TERMINAL" ]]; then
    ui_status "Terminal" "$AI_COLAB_TERMINAL ($AI_COLAB_ENVIRONMENT)" "${CYAN}"
    
    if [[ "$AI_COLAB_TERMINAL" == "iterm2" ]]; then
        ui_status "Optimizations" "iTerm2 active" "${BLUE}"
    elif [[ "$AI_COLAB_ENVIRONMENT" == "wsl" ]]; then
        ui_status "Optimizations" "WSL active" "${BLUE}"
    fi
fi

# Check for hcom
if ! has_command hcom; then
    ui_banner "Dependency Error" "${RED}"
    echo -e "${RED}Error: hcom is not installed.${NC}"
    echo -e "Please run ./install.sh first."
    exit 1
fi

# Check for tmux
if ! has_command tmux; then
    ui_banner "Dependency Error" "${RED}"
    echo -e "${RED}Error: tmux is not installed.${NC}"
    echo -e "Please run ./install.sh first."
    exit 1
fi

# 1. Project Detection
PROJECT_ROOT=$(detect_project_root 2>/dev/null || echo "$SCRIPT_DIR")
export PROJECT_ROOT
ui_status "Project Root" "$PROJECT_ROOT" "${GREEN}"

# 1.1 Project Artifact Detection & Migration
ui_title "Project Scanning" "${BLUE}"

if [[ -f "$SCRIPT_DIR/scripts/migrate-project.sh" ]]; then
    # Run detection (non-interactive mode first)
    bash "$SCRIPT_DIR/scripts/migrate-project.sh" "$PROJECT_ROOT" --detect-only 2>/dev/null || true
    
    # Check if migration is needed
    if [[ -f "$PROJECT_ROOT/.ai-colab-migration-pending" ]]; then
        echo -e "\n${YELLOW}═══════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}  Existing AI/LLM integrations detected!${NC}"
        echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "Found existing MCP configurations, product plans, or knowledge base artifacts."
        echo -e "${BLUE}Would you like to migrate these to ai-colab?${NC}"
        echo ""
        read -p "Run migration now? [Y/n]: " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
            echo -e "\n${BLUE}Starting migration...${NC}"
            export AI_COLAB_LAUNCHER=true
            bash "$SCRIPT_DIR/scripts/migrate-project.sh" "$PROJECT_ROOT"
            rm -f "$PROJECT_ROOT/.ai-colab-migration-pending"
            echo -e "\n${GREEN}✓ Migration complete. Continuing to launch...${NC}"
        else
            echo -e "\n${YELLOW}Migration skipped. You can run it later with:${NC}"
            echo -e "  ${BLUE}./scripts/migrate-project.sh${NC}"
        fi
        echo ""
    fi
fi

# Configuration Manager
CONFIG_MGR="$SCRIPT_DIR/scripts/config-manager.sh"

# Preferences handling via config-manager
load_pref() {
    bash "$CONFIG_MGR" get "$1" "${2:-}"
}
save_pref() {
    bash "$CONFIG_MGR" set "$1" "$2"
}

# 2. Interactive Selection
# Load previous choices from state if available
LAST_LAUNCH_CHOICE=$(bash "$CONFIG_MGR" state last_launch_choice 3)

ui_title "Component Configuration" "${BLUE}"
echo -e "Select components to launch:"
echo -e "  ${CYAN}1)${NC} Dashboard (hcom TUI + Agents)"
echo -e "  ${CYAN}2)${NC} Conductor (Project Manager)"
echo -e "  ${CYAN}3)${NC} Both (Recommended)"
echo ""
read -p "Choice [1-3, default $LAST_LAUNCH_CHOICE]: " LAUNCH_CHOICE
LAUNCH_CHOICE=${LAUNCH_CHOICE:-$LAST_LAUNCH_CHOICE}
bash "$CONFIG_MGR" state-set last_launch_choice "$LAUNCH_CHOICE"

DASHBOARD=false
CONDUCTOR=false

case "$LAUNCH_CHOICE" in
    1) DASHBOARD=true ;;
    2) CONDUCTOR=true ;;
    3) DASHBOARD=true; CONDUCTOR=true ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

# 3. Module Selection
ui_title "Module Addons" "${BLUE}"
MODULES_JSON=$(python3 "$SCRIPT_DIR/scripts/module-manager.py" list "$PROJECT_ROOT")

# Use python3 for portable JSON extraction
MOD_IDS=$(echo "$MODULES_JSON" | python3 -c 'import json, sys; print("\n".join([m["id"] for m in json.load(sys.stdin)]))' 2>/dev/null || echo "")
MOD_NAMES=$(echo "$MODULES_JSON" | python3 -c 'import json, sys; print("\n".join([m["name"] for m in json.load(sys.stdin)]))' 2>/dev/null || echo "")

# Iterate and ask
IFS=$'\n'
IDS_ARR=($MOD_IDS)
NAMES_ARR=($MOD_NAMES)

if [ ${#IDS_ARR[@]} -eq 0 ]; then
    echo -e "  ${YELLOW}(No additional modules found)${NC}"
else
    read -p "  Reconfigure Module Addons? [y/N]: " -n 1 -r; echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for i in "${!IDS_ARR[@]}"; do
            ID="${IDS_ARR[$i]}"
            NAME="${NAMES_ARR[$i]}"
            PREF_KEY="MODULE_$(echo "$ID" | tr '-' '_' | tr '[:lower:]' '[:upper:]')"
            LAST_VAL=$(load_pref "$PREF_KEY")
            LAST_VAL=${LAST_VAL:-false}

            PROMPT_VAL="n"
            [[ "$LAST_VAL" == "true" ]] && PROMPT_VAL="Y" || PROMPT_VAL="y"

            read -p "  Enable $NAME ($ID)? [$PROMPT_VAL/n]: " -n 1 -r; echo ""
            if [[ $REPLY =~ ^[Yy]$ ]] || ([[ -z $REPLY ]] && [[ "$LAST_VAL" == "true" ]]); then
                save_pref "$PREF_KEY" "true"
            else
                save_pref "$PREF_KEY" "false"
            fi
        done
    fi
fi

# Evaluate active module environment variables
eval "$(python3 "$SCRIPT_DIR/scripts/module-manager.py" env "$PROJECT_ROOT")"

# 3.1 Compute Backend (Spoke Architecture)
LAST_BACKEND=$(load_pref "compute.backend" "local")
ui_title "Remote Compute (Spokes)" "${BLUE}"
ui_box "The ai-colab Hub runs on this local machine. High-power agents
(Spokes) require external GPU compute for inference." "${BLUE}"
echo ""
ui_status "Current Backend" "$LAST_BACKEND" "${GREEN}"

read -p "  Configure Remote Compute Backend? [y/N]: " -n 1 -r; echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "  ${CYAN}1)${NC} NVIDIA NIM (Cloud-hosted nemoclaw - Recommended)"
    echo -e "  ${CYAN}2)${NC} Remote vLLM (Private network GPU server)"
    echo -e "  ${CYAN}3)${NC} RunPod (On-demand cloud GPU)"
    echo -e "  ${CYAN}4)${NC} Local Server (Use only if you have local GPU)"
    read -p "  Select backend [1-4]: " NEW_BACKEND
    case "$NEW_BACKEND" in
        1) COMPUTE_BACKEND="nvidia" ;;
        2) COMPUTE_BACKEND="vllm-remote" ;;
        3) COMPUTE_BACKEND="runpod" ;;
        *) COMPUTE_BACKEND="local" ;;
    esac
    save_pref "compute.backend" "$COMPUTE_BACKEND"
else
    COMPUTE_BACKEND="$LAST_BACKEND"
fi
export COMPUTE_BACKEND="$COMPUTE_BACKEND"

# Load backend-specific env vars if they exist
[ -f "$HOME/.ai-colab-env" ] && source "$HOME/.ai-colab-env"

# 4. Agent Selection (if dashboard)
DASHBOARD_FLAGS=""
if [ "$DASHBOARD" = true ]; then
    ui_title "Collaboration Fleet" "${BLUE}"
    ui_box "Select agents to enable multi-agent collaboration.
Spoke agents will use the $COMPUTE_BACKEND backend." "${BLUE}"
    echo ""

    read -p "  Reconfigure Collaboration Fleet? [y/N]: " -n 1 -r; echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Qwen
        DEFAULT_QWEN=$(load_pref "llm.qwen.enabled" "true")
        PROMPT_QWEN=$([[ "$DEFAULT_QWEN" == "true" ]] && echo "Y/n" || echo "y/N")
        read -p "  Include Qwen? [$PROMPT_QWEN]: " -n 1 -r; echo ""
        if [[ $REPLY =~ ^[Yy]$ ]] || ([[ -z $REPLY ]] && [[ "$DEFAULT_QWEN" == "true" ]]); then
            save_pref "llm.qwen.enabled" "true"
        else
            save_pref "llm.qwen.enabled" "false"
        fi

        # Gemini
        DEFAULT_GEMINI=$(load_pref "llm.gemini.enabled" "true")
        PROMPT_GEMINI=$([[ "$DEFAULT_GEMINI" == "true" ]] && echo "Y/n" || echo "y/N")
        read -p "  Include Gemini? [$PROMPT_GEMINI]: " -n 1 -r; echo ""
        if [[ $REPLY =~ ^[Yy]$ ]] || ([[ -z $REPLY ]] && [[ "$DEFAULT_GEMINI" == "true" ]]); then
            save_pref "llm.gemini.enabled" "true"
        else
            save_pref "llm.gemini.enabled" "false"
        fi

        # Spoke Agent: nemoclaw (NVIDIA NIM)
        if [ "$COMPUTE_BACKEND" == "nvidia" ]; then
            DEFAULT_NEMOCLAW=$(load_pref "llm.nemoclaw.enabled" "true")
            PROMPT_NEMOCLAW=$([[ "$DEFAULT_NEMOCLAW" == "true" ]] && echo "Y/n" || echo "y/N")
            read -p "  Include nemoclaw (NVIDIA NIM)? [$PROMPT_NEMOCLAW]: " -n 1 -r; echo ""
            if [[ $REPLY =~ ^[Yy]$ ]] || ([[ -z $REPLY ]] && [[ "$DEFAULT_NEMOCLAW" == "true" ]]); then
                save_pref "llm.nemoclaw.enabled" "true"
            else
                save_pref "llm.nemoclaw.enabled" "false"
            fi
        fi

        # Spoke Agent: vLLM
        if [[ "$COMPUTE_BACKEND" == "vllm-remote" || "$COMPUTE_BACKEND" == "local" ]]; then
            DEFAULT_VLLM=$(load_pref "llm.vllm.enabled" "false")
            PROMPT_VLLM=$([[ "$DEFAULT_VLLM" == "true" ]] && echo "Y/n" || echo "y/N")
            read -p "  Include vLLM Spoke? [$PROMPT_VLLM]: " -n 1 -r; echo ""
            if [[ $REPLY =~ ^[Yy]$ ]] || ([[ -z $REPLY ]] && [[ "$DEFAULT_VLLM" == "true" ]]); then
                LAST_VLLM_HOST=$(load_pref "llm.vllm.host" "192.168.0.193")
                read -p "  vLLM Host [default $LAST_VLLM_HOST]: " VLLM_HOST
                VLLM_HOST=${VLLM_HOST:-$LAST_VLLM_HOST}
                save_pref "llm.vllm.host" "$VLLM_HOST"
                save_pref "llm.vllm.enabled" "true"
            else
                save_pref "llm.vllm.enabled" "false"
            fi
        fi

        # Claude
        DEFAULT_CLAUDE=$(load_pref "llm.claude.enabled" "false")
        PROMPT_CLAUDE=$([[ "$DEFAULT_CLAUDE" == "true" ]] && echo "Y/n" || echo "y/N")
        read -p "  Include Claude? [$PROMPT_CLAUDE]: " -n 1 -r; echo ""
        if [[ $REPLY =~ ^[Yy]$ ]] || ([[ -z $REPLY ]] && [[ "$DEFAULT_CLAUDE" == "true" ]]); then
            save_pref "llm.claude.enabled" "true"
        else
            save_pref "llm.claude.enabled" "false"
        fi

        # DeepSeek
        DEFAULT_DEEPSEEK=$(load_pref "llm.deepseek.enabled" "false")
        PROMPT_DEEPSEEK=$([[ "$DEFAULT_DEEPSEEK" == "true" ]] && echo "Y/n" || echo "y/N")
        read -p "  Include DeepSeek? [$PROMPT_DEEPSEEK]: " -n 1 -r; echo ""
        if [[ $REPLY =~ ^[Yy]$ ]] || ([[ -z $REPLY ]] && [[ "$DEFAULT_DEEPSEEK" == "true" ]]); then
            save_pref "llm.deepseek.enabled" "true"
        else
            save_pref "llm.deepseek.enabled" "false"
        fi
    fi

    # Set DASHBOARD_FLAGS based on finalized preferences
    [[ $(load_pref "llm.qwen.enabled" "true") == "false" ]] && DASHBOARD_FLAGS+=" --no-qwen"
    [[ $(load_pref "llm.gemini.enabled" "true") == "false" ]] && DASHBOARD_FLAGS+=" --no-gemini"

    if [[ $(load_pref "llm.nemoclaw.enabled" "false") == "true" && "$COMPUTE_BACKEND" == "nvidia" ]]; then
        DASHBOARD_FLAGS+=" --add-nemoclaw"
        export NEMO_HOST="integrate.api.nvidia.com"
        export NEMO_BASE_URL="https://integrate.api.nvidia.com/v1"
    fi

    if [[ $(load_pref "llm.vllm.enabled" "false") == "true" && ("$COMPUTE_BACKEND" == "vllm-remote" || "$COMPUTE_BACKEND" == "local") ]]; then
        DASHBOARD_FLAGS+=" --vllm"
        VLLM_HOST=$(load_pref "llm.vllm.host" "192.168.0.193")
        export VLLM_BASE_URL="http://$VLLM_HOST:8000/v1"
    fi

    [[ $(load_pref "llm.claude.enabled" "false") == "true" ]] && DASHBOARD_FLAGS+=" --add-claude"
    [[ $(load_pref "llm.deepseek.enabled" "false") == "true" ]] && DASHBOARD_FLAGS+=" --add-deepseek"

    if [ "$CONDUCTOR" = true ]; then
        DASHBOARD_FLAGS+=" --conductor"
    fi
fi
# 4. Launching
ui_title "Finalizing Launch" "${BLUE}"
if [ "$DASHBOARD" = true ]; then
    echo -e "  Launching Unified Dashboard..."
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
