#!/usr/bin/env bash
# ai-colab Master Installer
# Installs project dependencies, LLM CLIs, and the Conductor Agent.
# Supports: --wizard (interactive), --reconfigure (modify existing), --auto (non-interactive)

set -e

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
    NC='\033[0m'
    has_command() { command -v "$1" >/dev/null 2>&1; }
fi

# Source terminal detection
if [ -f "$SCRIPT_DIR/scripts/terminal-detect.sh" ]; then
    source "$SCRIPT_DIR/scripts/terminal-detect.sh"
    init_terminal
fi

# Show guide
show_guide() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          ai-colab Installation Guide         ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Pathway 1: Interactive CLI Wizard (Recommended)${NC}"
    echo "  Best for: Developers who want a guided setup in their terminal."
    echo "  Command:  ${CYAN}./install.sh --wizard${NC}"
    echo ""
    echo -e "${YELLOW}Pathway 2: Docker / Web UI${NC}"
    echo "  Best for: Users who prefer a browser interface or containerization."
    echo "  Command:  ${CYAN}docker-compose up -d${NC}"
    echo "  Access:   http://localhost:8080"
    echo ""
    echo -e "${YELLOW}Pathway 3: Quick/Auto Install${NC}"
    echo "  Best for: CI/CD or experienced users who want a standard setup."
    echo "  Command:  ${CYAN}./install.sh --auto${NC}"
    echo ""
    echo -e "${YELLOW}Post-Installation:${NC}"
    echo "  Reconfigure: ${CYAN}./install.sh --reconfigure${NC}"
    echo "  Launch:      ${CYAN}./launch.sh${NC}"
    echo ""
    exit 0
}

# Parse command line arguments first
INSTALL_MODE="interactive"
RECONFIGURE_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --wizard|-w)
            INSTALL_MODE="wizard"
            shift
            ;;
        --reconfigure|-r)
            RECONFIGURE_MODE=true
            INSTALL_MODE="reconfigure"
            shift
            ;;
        --auto|-a)
            INSTALL_MODE="auto"
            shift
            ;;
        --guide|-g)
            show_guide
            ;;
        --help|-h)
            echo "ai-colab Master Installer"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --wizard, -w      Run interactive installation wizard"
            echo "  --reconfigure, -r Reconfigure existing installation"
            echo "  --auto, -a        Non-interactive auto-install (uses defaults)"
            echo "  --guide, -g       Show detailed installation guide"
            echo "  --help, -h        Show this help message"
            echo ""
            echo "Installation Pathways:"
            echo "  CLI:              ./install.sh --wizard"
            echo "  Web UI (Docker):  docker-compose up"
            echo "  Quick Install:    ./install.sh --auto"
            echo ""
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# Handle wizard mode
if [[ "$INSTALL_MODE" == "wizard" ]]; then
    if [[ -f "$SCRIPT_DIR/scripts/install-wizard.sh" ]]; then
        bash "$SCRIPT_DIR/scripts/install-wizard.sh"
        # Continue installation based on configuration
    else
        echo -e "${RED}Error: install-wizard.sh not found${NC}"
        exit 1
    fi
fi

# Handle reconfigure mode
if [[ "$INSTALL_MODE" == "reconfigure" ]]; then
    if [[ -f "$SCRIPT_DIR/scripts/install-wizard.sh" ]]; then
        exec bash "$SCRIPT_DIR/scripts/install-wizard.sh" --reconfigure
    else
        echo -e "${RED}Error: install-wizard.sh not found${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       ai-colab Master Installer       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""


# Terminal Detection & Optimization
if [[ -n "$AI_COLAB_TERMINAL" ]]; then
    echo -e "${GREEN}Terminal Detected:${NC} $AI_COLAB_TERMINAL ($AI_COLAB_ENVIRONMENT)"
    
    if [[ "$AI_COLAB_TERMINAL" == "iterm2" ]]; then
        echo -e "${BLUE}✓ iTerm2 detected - applying optimizations${NC}"
        echo -e "  - True color support enabled"
        echo -e "  - Unicode support enabled"
        echo -e "  - Shell integration available"
    elif [[ "$AI_COLAB_ENVIRONMENT" == "wsl" ]]; then
        echo -e "${BLUE}✓ WSL detected - applying optimizations${NC}"
        echo -e "  - Windows clipboard integration enabled"
        echo -e "  - Windows Terminal interop configured"
    fi
    echo ""
fi

# 1. Dependency Checks (Base)
echo -e "${GREEN}Checking base dependencies...${NC}"

# Check for Brew (macOS)
IS_MACOS=false
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MACOS=true
    if ! has_command brew; then
        echo -e "${YELLOW}Warning: Homebrew is not installed.${NC}"
        echo -e "Homebrew is recommended for installing many tools on macOS."
    fi
fi

# Check for Node (npm)
if ! has_command npm; then
    echo -e "${RED}Error: Node.js (npm) is not installed.${NC}"
    echo -e "Required for many AI CLIs. Please install Node.js first."
    exit 1
fi

# Check for Python
if ! has_command python3; then
    echo -e "${RED}Error: Python 3 is not installed.${NC}"
    echo -e "Required for NeMo CLI and other utilities."
    exit 1
fi

# Check for SQLite3 (required for blackboard)
if ! has_command sqlite3; then
    echo -e "${YELLOW}Warning: sqlite3 is missing. Required for hcom-kv (Blackboard).${NC}"
    if [[ "$IS_MACOS" == true ]] && has_command brew; then
        echo "Installing sqlite3 via brew..."
        brew install sqlite3
    fi
fi

# Check for Tmux (required for dashboard)
if ! has_command tmux; then
    echo -e "${YELLOW}Warning: tmux is missing. Required for the multi-agent dashboard.${NC}"
    if [[ "$IS_MACOS" == true ]] && has_command brew; then
        echo "Installing tmux via brew..."
        brew install tmux
    fi
fi

# Determine shell config file
SHELL_CONFIG=""
if [[ "$SHELL" == */zsh ]]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [[ "$SHELL" == */bash ]]; then
    SHELL_CONFIG="$HOME/.bashrc"
    if [[ "$OSTYPE" == "darwin"* ]] && [ -f "$HOME/.bash_profile" ]; then
        SHELL_CONFIG="$HOME/.bash_profile"
    fi
fi

# 2. hcom Installation
if ! has_command hcom; then
    echo -e "\n${YELLOW}hcom (Hook-Comms) is required for agent messaging and coordination.${NC}"
    read -p "Do you want to install hcom? [Y/n] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
        echo "Installing hcom..."
        
        # SECURE: Download, verify, then execute (not curl | bash)
        HCOM_INSTALL_SCRIPT=$(mktemp /tmp/hcom-install.XXXXXX.sh)
        trap "rm -f $HCOM_INSTALL_SCRIPT" EXIT
        
        echo "  Downloading hcom installer..."
        if curl -fsSL -o "$HCOM_INSTALL_SCRIPT" https://raw.githubusercontent.com/aannoo/hcom/main/install.sh; then
            echo "  Verifying installer..."
            # Basic verification: check script starts with shebang
            if head -1 "$HCOM_INSTALL_SCRIPT" | grep -q "^#!"; then
                echo "  Running installer..."
                bash "$HCOM_INSTALL_SCRIPT"
                echo -e "${GREEN}✓ hcom installed successfully${NC}"
            else
                print_error "Installer verification failed: invalid script format"
                exit 1
            fi
        else
            print_error "Failed to download hcom installer"
            exit 1
        fi

        # Source profile to make hcom available in the current script process
        if [ -n "$SHELL_CONFIG" ] && [ -f "$SHELL_CONFIG" ] && [[ "$SHELL_CONFIG" != *".zshrc" ]]; then
            echo -e "Sourcing $SHELL_CONFIG..."
            source "$SHELL_CONFIG"
        fi
        export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
    fi
else
    echo -e "${GREEN}✓ hcom is already installed.${NC}"
fi

# 2.1 Python Environment Detection & Dependency Installation
echo -e "\n${GREEN}Setting up Python Environment...${NC}"

PYTHON_ENV_MGR="$PROJECT_ROOT/scripts/python-env-manager.sh"
if [[ ! -x "$PYTHON_ENV_MGR" ]]; then
    chmod +x "$PYTHON_ENV_MGR"
fi

# Detect and create/activate environment
MANAGER=$("$PYTHON_ENV_MGR" detect)
echo -e "${BLUE}Detected environment manager: $MANAGER${NC}"

# Create environment if it doesn't exist
"$PYTHON_ENV_MGR" create

# Get activation command and source it
ACTIVATE_CMD=$("$PYTHON_ENV_MGR" activate-cmd)
echo -e "${BLUE}Activating environment: $ACTIVATE_CMD${NC}"
eval "$ACTIVATE_CMD"

# Set Python and Pip commands based on environment
PYTHON_CMD="python"
if [[ "$MANAGER" == "uv" ]]; then
    PIP_CMD="uv pip"
else
    PIP_CMD="python -m pip"
fi

# Function to check and install missing dependencies
install_python_deps() {
    local req_file="$1"
    local description="$2"

    if [[ -f "$req_file" ]]; then
        echo -e "\n${BLUE}Installing $description...${NC}"

        # Check which packages are missing
        local missing=()
        while IFS= read -r package; do
            # Skip comments and empty lines
            [[ -z "$package" || "$package" =~ ^# ]] && continue

            # Extract package name (before ==)
            local pkg_name=$(echo "$package" | cut -d'=' -f1)

            # Check if installed
            if ! $PYTHON_CMD -c "import ${pkg_name//-/_}" 2>/dev/null; then
                missing+=("$package")
            fi
        done < "$req_file"

        if [[ ${#missing[@]} -gt 0 ]]; then
            echo "  Installing missing packages: ${missing[*]}"
            $PIP_CMD install -r "$req_file" || echo -e "${YELLOW}  Warning: $description had issues${NC}"
        else
            echo -e "  ${GREEN}✓ All $description already installed${NC}"
        fi
    fi
}

# Install Web UI dependencies (includes vision support)
install_python_deps "$PROJECT_ROOT/requirements-webui.txt" "Web UI dependencies"

# Install MCP Server dependencies
install_python_deps "$PROJECT_ROOT/requirements-mcp.txt" "MCP Server dependencies"

# Install RAG System dependencies
install_python_deps "$PROJECT_ROOT/requirements-rag.txt" "RAG System dependencies"

# Install test dependencies if running tests
if [[ -f "$PROJECT_ROOT/requirements-test.txt" ]]; then
    install_python_deps "$PROJECT_ROOT/requirements-test.txt" "Test dependencies"
fi

# Check for optional vision dependencies
echo -e "\n${BLUE}Checking Vision/Screenshot Support...${NC}"
if $PYTHON_CMD -c "import pyautogui" 2>/dev/null && $PYTHON_CMD -c "import PIL" 2>/dev/null; then
    echo -e "  ${GREEN}✓ Vision support ready (pyautogui, Pillow)${NC}"
elif $PYTHON_CMD -c "import PIL" 2>/dev/null; then
    echo -e "  ${CYAN}○ Pillow installed (pyautogui requires X11 display)${NC}"
else
    echo -e "  ${YELLOW}⚠ Vision dependencies missing. Installing...${NC}"
    $PIP_CMD install pyautogui Pillow || echo -e "${YELLOW}  Warning: Vision support installation failed${NC}"
fi

echo -e "${GREEN}✓ Python dependencies installed${NC}"

# 3. LLM Support Selection
echo -e "\n${GREEN}Which LLMs do you wish to support?${NC}"
echo "1) Gemini (via gemini-cli)"
echo "2) Claude (via claude-code)"
echo "3) Qwen   (via qwen-code)"
echo "4) Ollama (local models)"
echo "5) NeMo   (via openai-python for nemo-cli.py)"
echo "6) DeepSeek (via deepseek-cli)"
echo "7) ELC      (via easy-llm-cli for vLLM support)"
echo "a) All of the above"
echo "n) None (skip to Conductor setup)"
echo ""

# Auto-mode: skip LLM selection, install common ones
if [[ "$INSTALL_MODE" == "auto" ]]; then
    LLM_CHOICE="1,3"  # Default: Gemini + Qwen
    echo -e "${BLUE}Auto mode: Selecting Gemini + Qwen${NC}"
else
    read -p "Enter your choices (e.g., 1,2,4 or 'a'): " LLM_CHOICE
fi

# Process choices
LLMS_TO_INSTALL=""
if [[ "$LLM_CHOICE" == "a" ]]; then
    LLMS_TO_INSTALL="gemini claude qwen ollama nemo deepseek elc"
elif [[ "$LLM_CHOICE" == "n" ]]; then
    LLMS_TO_INSTALL=""
else
    [[ "$LLM_CHOICE" == *"1"* ]] && LLMS_TO_INSTALL+=" gemini"
    [[ "$LLM_CHOICE" == *"2"* ]] && LLMS_TO_INSTALL+=" claude"
    [[ "$LLM_CHOICE" == *"3"* ]] && LLMS_TO_INSTALL+=" qwen"
    [[ "$LLM_CHOICE" == *"4"* ]] && LLMS_TO_INSTALL+=" ollama"
    [[ "$LLM_CHOICE" == *"5"* ]] && LLMS_TO_INSTALL+=" nemo"
    [[ "$LLM_CHOICE" == *"6"* ]] && LLMS_TO_INSTALL+=" deepseek"
    [[ "$LLM_CHOICE" == *"7"* ]] && LLMS_TO_INSTALL+=" elc"
fi

# Install Selected LLMs
for llm in $LLMS_TO_INSTALL; do
    case $llm in
        gemini)
            if ! has_command gemini; then
                echo -e "\n${BLUE}Installing Gemini CLI...${NC}"
                if [[ "$IS_MACOS" == true ]] && has_command brew; then
                    brew install gemini-cli
                else
                    npm install -g @google/gemini-cli
                fi
            else
                echo -e "  ✓ Gemini CLI is already installed."
            fi
            ;;
        claude)
            if ! has_command claude; then
                echo -e "\n${BLUE}Installing Claude CLI...${NC}"
                if [[ "$IS_MACOS" == true ]] && has_command brew; then
                    brew install --cask claude-code
                else
                    npm install -g @anthropic-ai/claude-code
                fi
            else
                echo -e "  ✓ Claude CLI is already installed."
            fi
            ;;
        qwen)
            if ! has_command qwen; then
                echo -e "\n${BLUE}Installing Qwen CLI...${NC}"
                if [[ "$IS_MACOS" == true ]] && has_command brew; then
                    brew install qwen-code
                else
                    npm install -g @qwen-code/qwen-code
                fi
            else
                echo -e "  ✓ Qwen CLI is already installed."
            fi
            ;;
        ollama)
            if ! has_command ollama; then
                echo -e "\n${BLUE}Installing Ollama...${NC}"
                if [[ "$IS_MACOS" == true ]] && has_command brew; then
                    brew install ollama
                else
                    # SECURE: Download, verify, then execute (not curl | bash)
                    OLLAMA_INSTALL_SCRIPT=$(mktemp /tmp/ollama-install.XXXXXX.sh)
                    trap "rm -f $OLLAMA_INSTALL_SCRIPT" EXIT
                    
                    echo "  Downloading Ollama installer..."
                    if curl -fsSL -o "$OLLAMA_INSTALL_SCRIPT" https://ollama.com/install.sh; then
                        echo "  Verifying installer..."
                        if head -1 "$OLLAMA_INSTALL_SCRIPT" | grep -q "^#!"; then
                            echo "  Running installer..."
                            bash "$OLLAMA_INSTALL_SCRIPT"
                            echo -e "${GREEN}✓ Ollama installed successfully${NC}"
                        else
                            print_error "Installer verification failed: invalid script format"
                            exit 1
                        fi
                    else
                        print_error "Failed to download Ollama installer"
                        exit 1
                    fi
                fi
            else
                echo -e "  ✓ Ollama is already installed."
            fi
            ;;
        nemo)
            echo -e "\n${BLUE}Installing NeMo dependencies...${NC}"
            $PIP_CMD install openai
            ;;
        deepseek)
            if ! has_command deepseek; then
                echo -e "\n${BLUE}Installing DeepSeek CLI...${NC}"
                npm install -g run-deepseek-cli
            else
                echo -e "  ✓ DeepSeek CLI is already installed."
            fi
            ;;
        elc)
            if ! has_command elc; then
                echo -e "\n${BLUE}Installing easy-llm-cli...${NC}"
                npm install -g easy-llm-cli
            else
                echo -e "  ✓ easy-llm-cli is already installed."
            fi
            ;;
    esac
done

# 4. Optional: Addon Modules (Dynamic Discovery)
echo -e "\n${GREEN}Discovering Addon Modules...${NC}"

# Use module-manager.sh to discover all available modules
if [[ -f "$SCRIPT_DIR/scripts/module-manager.sh" ]]; then
    MODULES_DIR="$SCRIPT_DIR/modules"
    
    if [[ -d "$MODULES_DIR" ]]; then
        # Discover all modules with valid manifests
        bash "$SCRIPT_DIR/scripts/module-manager.sh" list | grep -v "^Available\|^$" | while read -r line; do
            # Parse module info: "  ✓ module-id (active)" or "  ○ module-id"
            module_id=$(echo "$line" | sed 's/.*[✓○] \([^ ]*\).*/\1/' | tr -d ' ')
            is_active=$(echo "$line" | grep -q "✓" && echo "true" || echo "false")
            
            if [[ -n "$module_id" && "$module_id" != "Available" ]]; then
                echo -e "${BLUE}Found Module:${NC} $module_id"
                
                # Check for module-specific install script
                module_install="$MODULES_DIR/$module_id/scripts/install-deps.sh"
                if [[ -f "$module_install" ]]; then
                    read -p "  Run installation for $module_id? [Y/n] " -n 1 -r
                    echo ""
                    if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
                        echo -e "  ${BLUE}Running module installation...${NC}"
                        bash "$module_install" || echo -e "  ${YELLOW}Warning: Module installation had warnings${NC}"
                    fi
                else
                    echo -e "  ${GREEN}✓ No installation required${NC}"
                fi
                
                # Set module preference
                pref_key="MODULE_$(echo "$module_id" | tr '-' '_' | tr '[:lower:]' '[:upper:]')"
                if [[ "$is_active" == "true" ]]; then
                    echo "$pref_key=true" >> "$SCRIPT_DIR/.ai-colab-prefs"
                fi
            fi
        done
        
        # SECURITY: Set secure file permissions on prefs file
        chmod 600 "$SCRIPT_DIR/.ai-colab-prefs" 2>/dev/null || true
    else
        echo -e "${YELLOW}○ No modules directory found${NC}"
    fi
else
    echo -e "${YELLOW}○ Module manager not found, skipping module discovery${NC}"
fi

# 4.1 Compute Backend Selection
echo -e "\n${GREEN}Select Compute Backend for High-Power Agents:${NC}"
echo "1) NVIDIA NIM API (Hosted)"
echo "2) RunPod Serverless/Pods"
echo "3) Local Server (vLLM / Ollama)"
echo "n) None (skip configuration)"
echo ""

# Auto-mode: default to local
if [[ "$INSTALL_MODE" == "auto" ]]; then
    BACKEND_CHOICE="3"
    echo -e "${BLUE}Auto mode: Selecting Local backend${NC}"
else
    read -p "Select backend [1-3, default 3]: " BACKEND_CHOICE
fi
BACKEND_CHOICE=${BACKEND_CHOICE:-3}

COMPUTE_BACKEND="local"
case "$BACKEND_CHOICE" in
    1)
        COMPUTE_BACKEND="nvidia"
        read -p "Enter NVIDIA API Key: " NVIDIA_API_KEY
        echo "export NVIDIA_API_KEY=$NVIDIA_API_KEY" >> "$HOME/.ai-colab-env"
        ;;
    2)
        COMPUTE_BACKEND="runpod"
        read -p "Enter RunPod API Key: " RUNPOD_API_KEY
        echo "export RUNPOD_API_KEY=$RUNPOD_API_KEY" >> "$HOME/.ai-colab-env"
        ;;
    3)
        COMPUTE_BACKEND="local"
        ;;
esac
echo "MODULE_COMPUTE_BACKEND=$COMPUTE_BACKEND" >> "$SCRIPT_DIR/.ai-colab-prefs"
echo -e "  ✓ Compute backend set to: ${BLUE}$COMPUTE_BACKEND${NC}"

# 5. Conductor Agent Setup
echo -e "\n${GREEN}Setting up Global Conductor Agent...${NC}"
if [ -f "$SCRIPT_DIR/scripts/conductor/install.sh" ]; then
    # Run conductor installer non-interactively
    bash "$SCRIPT_DIR/scripts/conductor/install.sh" --auto 2>/dev/null || \
    bash "$SCRIPT_DIR/scripts/conductor/install.sh" 2>&1 | head -20
else
    echo -e "${YELLOW}○ Conductor install script not found (optional)${NC}"
fi

# 6. Terminal-Specific Configuration
echo -e "\n${GREEN}Setting up terminal-specific optimizations...${NC}"

if [[ -n "$AI_COLAB_TERMINAL" ]]; then
    CONFIG_DIR="$SCRIPT_DIR/config"
    mkdir -p "$CONFIG_DIR"
    
    case "$AI_COLAB_TERMINAL" in
        iterm2)
            TMUX_CONFIG="$CONFIG_DIR/tmux.iterm2.conf"
            if [[ -f "$TMUX_CONFIG" ]]; then
                echo -e "${BLUE}✓ iTerm2 configuration available${NC}"
                echo -e "  Config: $TMUX_CONFIG"
                
                # Offer to install as ~/.tmux.conf if no existing config
                if [[ ! -f "$HOME/.tmux.conf" ]]; then
                    read -p "  Install as your default tmux config? [Y/n] " -n 1 -r
                    echo ""
                    if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
                        cp "$TMUX_CONFIG" "$HOME/.tmux.conf"
                        echo -e "  ${GREEN}✓ Installed to ~/.tmux.conf${NC}"
                    fi
                fi
            fi
            ;;
        windows_terminal)
            TMUX_CONFIG="$CONFIG_DIR/tmux.windows-terminal.conf"
            if [[ -f "$TMUX_CONFIG" ]]; then
                echo -e "${BLUE}✓ Windows Terminal configuration available${NC}"
                echo -e "  Config: $TMUX_CONFIG"
                
                if [[ ! -f "$HOME/.tmux.conf" ]]; then
                    read -p "  Install as your default tmux config? [Y/n] " -n 1 -r
                    echo ""
                    if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
                        cp "$TMUX_CONFIG" "$HOME/.tmux.conf"
                        echo -e "  ${GREEN}✓ Installed to ~/.tmux.conf${NC}"
                    fi
                fi
            fi
            ;;
        *)
            echo -e "${YELLOW}○ Using default tmux configuration${NC}"
            ;;
    esac
else
    echo -e "${YELLOW}○ Terminal detection skipped (run manually with: scripts/terminal-detect.sh)${NC}"
fi

if [ -n "$SHELL_CONFIG" ] && [ -f "$SHELL_CONFIG" ] && [[ "$SHELL_CONFIG" != *".zshrc" ]]; then
    echo -e "\n${BLUE}Sourcing $SHELL_CONFIG...${NC}"
    source "$SHELL_CONFIG"
fi

# 7. Final Verification
echo -e "\n${BLUE}Installation complete!${NC}"
echo -e "Some changes may require restarting your terminal or running:"
echo -e "  source $SHELL_CONFIG"
echo ""
echo -e "${GREEN}Try running './launch.sh' to get started.${NC}"
echo -e "Happy collaborating! 🚀"
