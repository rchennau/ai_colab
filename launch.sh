#!/usr/bin/env bash
# ai-colab Unified Launcher
# Launches the multi-agent dashboard, conductor, and selected agents.
# Now with terminal-specific optimizations for iTerm2, WSL, and more.
#
# Options:
#   --rag-watcher    Start RAG file watcher for auto-reindexing

set -e

# 0. Argument Parsing (Pre-launch)
INTERACTIVE=true
RAG_WATCHER=false
SHOW_HELP=false
for arg in "$@"; do
    if [[ "$arg" == "--no-interactive" || "$arg" == "--auto" ]]; then
        INTERACTIVE=false
        break
    elif [[ "$arg" == "--rag-watcher" ]]; then
        RAG_WATCHER=true
    elif [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
        SHOW_HELP=true
    fi
done

# Show help if requested
if [[ "$SHOW_HELP" == "true" ]]; then
    cat << EOF
ai-colab Unified Launcher

Usage: ./launch.sh [options]

Options:
  --rag-watcher     Start RAG file watcher for auto-reindexing
  --no-interactive  Non-interactive mode (use saved preferences)
  --auto            Alias for --no-interactive
  --help, -h        Show this help message

Examples:
  ./launch.sh                  # Interactive launch
  ./launch.sh --rag-watcher    # Launch with RAG auto-indexing
  ./launch.sh --auto           # Non-interactive launch

Launch Targets (via interactive selection):
  - Web UI (Flask dashboard on http://localhost:8080)
  - Unified Dashboard (tmux-based)
  - Conductor Agent

EOF
    exit 0
fi

# Find script directory - resolve ALL symlinks to get actual physical path
get_script_dir() {
    # Use $0 if BASH_SOURCE is empty (happens when sourced)
    local source="${BASH_SOURCE[0]:-$0}"
    
    # If source is relative, make it absolute
    [[ $source != /* ]] && source="$(pwd)/$source"
    
    # Resolve all symlinks
    while [ -h "$source" ]; do
        local dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ $source != /* ]] && source="$dir/$source"
    done
    
    # Get the directory and resolve it physically
    local dir="$(cd -P "$(dirname "$source")" && pwd -P)"
    echo "$dir"
}

SCRIPT_DIR="$(get_script_dir)"
PROJECT_ROOT="$SCRIPT_DIR"
export PROJECT_ROOT

if [ -f "$SCRIPT_DIR/scripts/utils.sh" ]; then
    source "$SCRIPT_DIR/scripts/utils.sh"
else
    # Fallback colors if utils not found
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
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

# Check Python dependencies
echo -e "\n${BLUE}Checking Python Dependencies...${NC}"
PYTHON_DEPS_OK=true

# Check critical Python packages
for pkg in flask flask_cors flask_limiter redis aiohttp; do
    if ! python3 -c "import ${pkg}" 2>/dev/null; then
        echo -e "  ${YELLOW}⚠ Missing: ${pkg}${NC}"
        PYTHON_DEPS_OK=false
    fi
done

# Check vision packages (optional)
VISION_AVAILABLE=false
if python3 -c "import pyautogui" 2>/dev/null && python3 -c "import PIL" 2>/dev/null; then
    echo -e "  ${GREEN}✓ Vision support available${NC}"
    VISION_AVAILABLE=true
else
    echo -e "  ${CYAN}○ Vision support not installed (optional)${NC}"
fi

# Check RAG packages (optional)
RAG_AVAILABLE=false
if python3 -c "import sentence_transformers" 2>/dev/null; then
    echo -e "  ${GREEN}✓ RAG system available${NC}"
    RAG_AVAILABLE=true
else
    echo -e "  ${YELLOW}⚠ RAG system not installed (recommended for KB search)${NC}"
fi

# If critical deps missing, offer to install
if [[ "$PYTHON_DEPS_OK" == "false" ]]; then
    echo -e "\n${YELLOW}Some Python dependencies are missing.${NC}"
    
    # Auto-mode: install automatically
    if [[ "$INTERACTIVE" == "false" ]]; then
        echo -e "${BLUE}Auto mode: Installing dependencies...${NC}"
        INSTALL_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install.sh"
        if [[ -f "$INSTALL_SCRIPT" ]]; then
            bash "$INSTALL_SCRIPT" --auto
        else
            print_error "Could not find install.sh"
            echo -e "${YELLOW}Please run: pip3 install -r requirements-webui.txt${NC}"
        fi
    else
        # Interactive mode: ask
        read -p "Install now? [Y/n] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
            echo -e "\n${BLUE}Installing dependencies...${NC}"
            INSTALL_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install.sh"
            if [[ -f "$INSTALL_SCRIPT" ]]; then
                bash "$INSTALL_SCRIPT" --auto
            else
                print_error "Could not find install.sh at $INSTALL_SCRIPT"
                echo -e "${YELLOW}Please run: pip3 install -r requirements-webui.txt${NC}"
            fi
        fi
    fi
fi

# Offer to install RAG if not available (interactive mode only)
if [[ "$RAG_AVAILABLE" == "false" && "$INTERACTIVE" == "true" ]]; then
    echo -e "\n${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  RAG System Not Detected${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "The RAG (Retrieval-Augmented Generation) system provides:"
    echo -e "  • Semantic search across your codebase"
    echo -e "  • Knowledge base integration for LLM context"
    echo -e "  • Enhanced Debug Mode capabilities"
    echo ""
    echo -e "${BLUE}Would you like to install RAG dependencies now?${NC}"
    echo -e "${YELLOW}  (Requires: sentence-transformers, faiss-cpu, watchdog)${NC}"
    echo ""
    read -p "  Install RAG system? [Y/n]: " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
        echo -e "\n${BLUE}Installing RAG system...${NC}"
        if [[ -f "$INSTALL_SCRIPT" ]]; then
            # Install RAG requirements
            pip3 install -r "$PROJECT_ROOT/requirements-rag.txt" 2>/dev/null || \
            pip3 install sentence-transformers faiss-cpu watchdog
            
            if python3 -c "import sentence_transformers" 2>/dev/null; then
                echo -e "\n${GREEN}✓ RAG system installed successfully${NC}"
                RAG_AVAILABLE=true
            else
                echo -e "\n${YELLOW}⚠ RAG installation incomplete. Run manually:${NC}"
                echo -e "  ${BLUE}pip3 install -r requirements-rag.txt${NC}"
            fi
        else
            pip3 install sentence-transformers faiss-cpu watchdog
        fi
    else
        echo -e "\n${CYAN}RAG installation skipped. Install later with:${NC}"
        echo -e "  ${BLUE}pip3 install -r requirements-rag.txt${NC}"
    fi
    echo ""
fi

# 1. Project Detection
# Ensure PROJECT_ROOT is set correctly (launch.sh is in project root)
if [[ -f "$SCRIPT_DIR/install.sh" ]]; then
    PROJECT_ROOT="$SCRIPT_DIR"
else
    PROJECT_ROOT=$(detect_project_root 2>/dev/null || echo "$SCRIPT_DIR")
fi
export PROJECT_ROOT
ui_status "Project Root" "$PROJECT_ROOT" "${GREEN}"

# 1.1 Project Artifact Detection & Migration
if [[ -f "$SCRIPT_DIR/scripts/migrate-project.sh" ]]; then
    # Run detection (non-interactive mode first)
    bash "$SCRIPT_DIR/scripts/migrate-project.sh" "$PROJECT_ROOT" --detect-only 2>/dev/null || true
    
    # Check if migration is needed
    if [[ -f "$PROJECT_ROOT/.ai-colab-migration-pending" ]]; then
        if [ "$INTERACTIVE" = true ]; then
            echo -e "\n${YELLOW}═══════════════════════════════════════════════════════${NC}"
            echo -e "${YELLOW}  Existing AI/LLM integrations detected!${NC}"
            echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
            echo ""
            echo -e "Found existing MCP configurations, product plans, or knowledge base artifacts."
            echo -e "${BLUE}Would you like to migrate these to ai-colab?${NC}"
            echo ""
            read -p "  Run migration now? [Y/n]: " -n 1 -r
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
        else
             log_info "Project migration pending. Run ./scripts/migrate-project.sh to import existing artifacts."
        fi
        echo ""
    fi
fi

# Configuration Manager
CONFIG_MGR="$SCRIPT_DIR/config-manager.sh"

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

if [ "$INTERACTIVE" = true ]; then
    ui_banner "Launch Mode Selection" "${BLUE}"
    echo ""
    echo -e "Select launch mode:"
    echo -e "  ${CYAN}1)${NC} Dashboard (tmux-based)"
    echo -e "      hcom TUI + Agents + Conductor in terminal panes"
    echo -e "  ${CYAN}2)${NC} WebUI (Browser-based)"
    echo -e "      Web interface with embedded terminal panels"
    echo -e "  ${CYAN}3)${NC} Debug Mode (Single Agent)"
    echo -e "      Dedicated LLM CLI with KB/RAG for troubleshooting"
    echo ""
    read -p "  Choice [1-3, default $LAST_LAUNCH_CHOICE]: " LAUNCH_CHOICE
    LAUNCH_CHOICE=${LAUNCH_CHOICE:-$LAST_LAUNCH_CHOICE}
else
    LAUNCH_CHOICE=$LAST_LAUNCH_CHOICE
fi
bash "$CONFIG_MGR" state-set last_launch_choice "$LAUNCH_CHOICE"

DASHBOARD=false
CONDUCTOR=false
WEBUI=false
DEBUG=false

case "$LAUNCH_CHOICE" in
    1) DASHBOARD=true; CONDUCTOR=true ;;
    2) WEBUI=true ;;
    3) DEBUG=true ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

# 3. Module Status Display
# Show available and loaded modules early in the launch process
ui_title "Module Addons" "${BLUE}"

# Discover modules
MODULES_DIR="$PROJECT_ROOT/modules"
if [[ -d "$MODULES_DIR" ]]; then
    echo -e "${CYAN}Available Modules:${NC}"
    
    # List all modules with their status
    for module_dir in "$MODULES_DIR"/*/; do
        if [[ -f "${module_dir}module.toml" ]]; then
            MODULE_ID=$(basename "$module_dir")
            MODULE_TOML="${module_dir}module.toml"
            
            # Extract module name and description from toml
            MODULE_NAME=$(grep "^name = " "$MODULE_TOML" 2>/dev/null | sed 's/name = "//; s/"$//')
            MODULE_DESC=$(grep "^description = " "$MODULE_TOML" 2>/dev/null | sed 's/description = "//; s/"$//')
            MODULE_VERSION=$(grep "^version = " "$MODULE_TOML" 2>/dev/null | sed 's/version = "//; s/"$//')
            
            # Check if module is enabled
            PREF_KEY="MODULE_$(echo "$MODULE_ID" | tr '-' '_' | tr '[:lower:]' '[:upper:]')"
            IS_ENABLED=$(bash "$CONFIG_MGR" get "$PREF_KEY" "false" 2>/dev/null)
            
            if [[ "$IS_ENABLED" == "true" ]]; then
                STATUS_ICON="${GREEN}✓${NC}"
                STATUS_TEXT="${GREEN}Loaded${NC}"
            else
                STATUS_ICON="${YELLOW}○${NC}"
                STATUS_TEXT="${YELLOW}Available${NC}"
            fi
            
            echo -e "  ${STATUS_ICON} ${BLUE}${MODULE_NAME}${NC} (${MODULE_ID})"
            echo -e "      ${STATUS_TEXT} • v${MODULE_VERSION}"
            if [[ -n "$MODULE_DESC" ]]; then
                echo -e "      ${CYAN}${MODULE_DESC}${NC}"
            fi
            echo ""
        fi
    done
    
    # Show template modules for developers
    echo -e "${CYAN}Module Templates (for development):${NC}"
    echo -e "  ${BLUE}• atari-8bit${NC} - Example module with conductor commands, periodic hooks, dashboard sections"
    echo -e "  ${BLUE}• mock-test${NC} - Simple test module for verifying plugin system"
    echo -e "  ${YELLOW}→ Use these as templates for creating new modules${NC}"
    echo ""
else
    echo -e "  ${YELLOW}(No modules directory found)${NC}"
fi

# 3.1 Module Selection (if not WebUI)
if [ "$WEBUI" = false ]; then
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
        # List current configuration
        echo -e "  ${BLUE}Current Addons:${NC}"
        ANY_ENABLED=false
        for i in "${!IDS_ARR[@]}"; do
            ID="${IDS_ARR[$i]}"
            NAME="${NAMES_ARR[$i]}"
            PREF_KEY="MODULE_$(echo "$ID" | tr '-' '_' | tr '[:lower:]' '[:upper:]')"
            if [[ "$(load_pref "$PREF_KEY" "false")" == "true" ]]; then
                echo -e "    ${GREEN}• $NAME ($ID)${NC}"
                ANY_ENABLED=true
            fi
        done
        [[ "$ANY_ENABLED" == "false" ]] && echo -e "    ${YELLOW}(None enabled)${NC}"
        echo ""

        if [ "$INTERACTIVE" = true ]; then
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

    if [ "$INTERACTIVE" = true ]; then
        read -p "  Configure Remote Compute Backend? [y/N]: " -n 1 -r; echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "  ${CYAN}1)${NC} NVIDIA NIM (Hosted nemoclaw spoke - Recommended)"
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

        # List current configuration
        echo -e "  ${BLUE}Current Fleet:${NC}"
        [[ $(load_pref "llm.qwen.enabled" "true") == "true" ]] && echo -e "    ${GREEN}• Qwen${NC}"
        [[ $(load_pref "llm.gemini.enabled" "true") == "true" ]] && echo -e "    ${GREEN}• Gemini${NC}"
        [[ $(load_pref "llm.nemoclaw.enabled" "false") == "true" && "$COMPUTE_BACKEND" == "nvidia" ]] && echo -e "    ${GREEN}• NVIDIA nemoclaw${NC}"
        [[ $(load_pref "llm.vllm.enabled" "false") == "true" && ("$COMPUTE_BACKEND" == "vllm-remote" || "$COMPUTE_BACKEND" == "local") ]] && echo -e "    ${GREEN}• vLLM Spoke (${YELLOW}$(load_pref "llm.vllm.host" "192.168.0.193")${NC})"
        [[ $(load_pref "llm.claude.enabled" "false") == "true" ]] && echo -e "    ${GREEN}• Anthropic Claude${NC}"
        [[ $(load_pref "llm.deepseek.enabled" "false") == "true" ]] && echo -e "    ${GREEN}• DeepSeek${NC}"
        echo ""

        if [ "$INTERACTIVE" = true ]; then
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

                # Spoke Agent: NVIDIA nemoclaw (NIM)
                if [ "$COMPUTE_BACKEND" == "nvidia" ]; then
                    DEFAULT_NEMOCLAW=$(load_pref "llm.nemoclaw.enabled" "true")
                    PROMPT_NEMOCLAW=$([[ "$DEFAULT_NEMOCLAW" == "true" ]] && echo "Y/n" || echo "y/N")
                    read -p "  Include NVIDIA nemoclaw (NIM Architect)? [$PROMPT_NEMOCLAW]: " -n 1 -r; echo ""
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

                # Anthropic Claude
                DEFAULT_CLAUDE=$(load_pref "llm.claude.enabled" "false")
                PROMPT_CLAUDE=$([[ "$DEFAULT_CLAUDE" == "true" ]] && echo "Y/n" || echo "y/N")
                read -p "  Include Anthropic Claude? [$PROMPT_CLAUDE]: " -n 1 -r; echo ""
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
        fi

        # Set DASHBOARD_FLAGS based on finalized preferences
        [[ $(load_pref "llm.qwen.enabled" "true") == "false" ]] && DASHBOARD_FLAGS+=" --no-qwen"
        [[ $(load_pref "llm.gemini.enabled" "true") == "false" ]] && DASHBOARD_FLAGS+=" --no-gemini"
        [[ $(load_pref "llm.vllm.enabled" "false") == "false" ]] && DASHBOARD_FLAGS+=" --no-vllm"

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
fi

# 4. Launching
ui_title "Finalizing Launch" "${BLUE}"

# Start RAG file watcher if requested
if [[ "$RAG_WATCHER" == "true" ]]; then
    ui_status "RAG Watcher" "Starting file watcher for auto-reindexing" "${CYAN}"
    
    # Check if watchdog is installed
    if python3 -c "import watchdog" 2>/dev/null; then
        # Start watcher in background
        python3 << 'PYTHON_EOF' &
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from rag.watcher.file_watcher import DocumentWatcher
from pathlib import Path

project_root = Path(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
index_path = project_root / ".ai-colab" / "rag" / "index.db"

watcher = DocumentWatcher(str(index_path))
watcher.start()

print(f"RAG file watcher started (PID: {os.getpid()})")
print("Watching for document changes...")

try:
    while True:
        import time
        time.sleep(1)
except KeyboardInterrupt:
    print("\nStopping RAG watcher...")
    watcher.stop()
PYTHON_EOF
        RAG_WATCHER_PID=$!
        export RAG_WATCHER_PID
    else
        ui_status "RAG Watcher" "watchdog not installed. Install with: pip install watchdog" "${YELLOW}"
    fi
fi

if [ "$WEBUI" = true ]; then
    ui_banner "Launching Web UI" "${GREEN}"
    echo ""
    echo -e "  Starting Flask server..."
    echo ""

    # Ensure logs directory exists
    mkdir -p "$PROJECT_ROOT/logs"

    if [ -d "$SCRIPT_DIR/webui-venv" ]; then
        source "$SCRIPT_DIR/webui-venv/bin/activate"
    fi

    # Start WebUI in background with output redirected to log file
    python3 "$SCRIPT_DIR/../webui/app.py" >> "$PROJECT_ROOT/logs/webui.log" 2>&1 &
    WEBUI_PID=$!

    # Wait for server to start
    sleep 3

    # Check if server is running
    if kill -0 $WEBUI_PID 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Web UI started successfully!"
        echo -e "${BLUE}➜${NC} Open in browser: ${CYAN}http://localhost:8080${NC}"
        echo -e "${BLUE}➜${NC} Logs: $PROJECT_ROOT/logs/webui.log"
        echo ""
        
        # Interactive menu loop
        while true; do
            echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
            echo -e "${YELLOW}  Web UI is running${NC}"
            echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
            echo ""
            echo -e "  ${CYAN}1)${NC} Open in browser"
            echo -e "  ${CYAN}2)${NC} Debug Mode (launch CLI agent)"
            echo -e "  ${CYAN}3)${NC} Exit (stop Web UI and exit)"
            echo ""
            read -p "  Choice [1-3]: " WEBUI_CHOICE

            case "$WEBUI_CHOICE" in
                1)
                    echo ""
                    echo -e "${GREEN}➜${NC} Web UI is available at: ${CYAN}http://localhost:8080${NC}"
                    echo -e "${CYAN}   (Copy and paste into your browser)${NC}"
                    echo ""
                    ;;
                2)
                    echo ""
                    echo -e "${YELLOW}Launching Debug Mode...${NC}"
                    echo ""
                    
                    # Stop WebUI before debug mode
                    kill $WEBUI_PID 2>/dev/null
                    wait $WEBUI_PID 2>/dev/null
                    
                    # Launch debug mode
                    cd "$PROJECT_ROOT"
                    exec bash "$SCRIPT_DIR/scripts/debug-mode.sh"
                    ;;
                3)
                    echo ""
                    echo -e "${YELLOW}Stopping Web UI...${NC}"
                    kill $WEBUI_PID 2>/dev/null
                    
                    # Wait for process to terminate (up to 5 seconds)
                    for i in {1..5}; do
                        if ! kill -0 $WEBUI_PID 2>/dev/null; then
                            break
                        fi
                        sleep 1
                    done
                    
                    # Verify process stopped
                    if ! kill -0 $WEBUI_PID 2>/dev/null; then
                        echo -e "${GREEN}✓${NC} Web UI stopped"
                        echo ""
                        echo -e "${GREEN}Session ended. Happy collaborating! 🚀${NC}"
                        echo ""
                        exit 0
                    else
                        echo -e "${RED}✗${NC} Web UI did not stop gracefully"
                        echo -e "${YELLOW}Force killing...${NC}"
                        kill -9 $WEBUI_PID 2>/dev/null
                        sleep 1
                        if ! kill -0 $WEBUI_PID 2>/dev/null; then
                            echo -e "${GREEN}✓${NC} Web UI force stopped"
                            echo ""
                            echo -e "${GREEN}Session ended. Happy collaborating! 🚀${NC}"
                            echo ""
                        fi
                        exit 0
                    fi
                    ;;
                *)
                    echo -e "${RED}Invalid choice. Please select 1, 2, or 3.${NC}"
                    ;;
            esac
        done
    else
        echo -e "${RED}✗${NC} Web UI failed to start. Check logs: $PROJECT_ROOT/logs/webui.log"
        exit 1
    fi
elif [ "$DEBUG" = true ]; then
    # Debug Mode - Single Agent with KB/RAG
    ui_banner "Debug Mode - AI Assistant" "${YELLOW}"
    echo ""
    echo -e "Select AI agent for debugging:"
    echo -e "  ${CYAN}1)${NC} Qwen (qwen-code)"
    echo -e "  ${CYAN}2)${NC} Gemini (gemini-cli)"
    echo -e "  ${CYAN}3)${NC} Claude (claude-code)"
    echo -e "  ${CYAN}4)${NC} DeepSeek (deepseek-cli)"
    echo ""
    read -p "  Choice [1-4]: " DEBUG_CHOICE

    AGENT=""
    case "$DEBUG_CHOICE" in
        1) AGENT="qwen" ;;
        2) AGENT="gemini" ;;
        3) AGENT="claude" ;;
        4) AGENT="deepseek" ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac

    echo ""
    echo -e "${GREEN}Starting debug mode with $AGENT...${NC}"
    echo ""

    cd "$PROJECT_ROOT"
    exec bash "$SCRIPT_DIR/scripts/debug-mode.sh" "$AGENT"

elif [ "$DASHBOARD" = true ]; then
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
