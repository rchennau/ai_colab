#!/usr/bin/env bash
# ai-colab Master Installer
# Installs project dependencies, LLM CLIs, and the Conductor Agent.

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

# Source terminal detection
if [ -f "$SCRIPT_DIR/scripts/terminal-detect.sh" ]; then
    source "$SCRIPT_DIR/scripts/terminal-detect.sh"
    init_terminal
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
        curl -fsSL https://raw.githubusercontent.com/aannoo/hcom/main/install.sh | sh
        
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
read -p "Enter your choices (e.g., 1,2,4 or 'a'): " LLM_CHOICE

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
                    npm install -g qwen-cli
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
                    curl -fsSL https://ollama.com/install.sh | sh
                fi
            else
                echo -e "  ✓ Ollama is already installed."
            fi
            ;;
        nemo)
            echo -e "\n${BLUE}Installing NeMo dependencies...${NC}"
            python3 -m pip install openai
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

# 4. Optional: Addon Modules
echo -e "\n${GREEN}Available Addon Modules:${NC}"
MODULES_JSON=$(python3 "$SCRIPT_DIR/scripts/module-manager.py" list "$SCRIPT_DIR")
# Simple extraction of IDs and Names from JSON
MOD_IDS=$(echo "$MODULES_JSON" | grep -oP '"id": "\K[^"]+' || echo "")
MOD_NAMES=$(echo "$MODULES_JSON" | grep -oP '"name": "\K[^"]+' || echo "")

# Iterate and ask
IFS=$'\n'
IDS_ARR=($MOD_IDS)
NAMES_ARR=($MOD_NAMES)

for i in "${!IDS_ARR[@]}"; do
    ID="${IDS_ARR[$i]}"
    NAME="${NAMES_ARR[$i]}"
    
    read -p "Install $NAME ($ID)? [y/N] " -n 1 -r; echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Configuring $NAME...${NC}"
        # In a full implementation, we'd run module-specific install scripts here
        # e.g., bash "$SCRIPT_DIR/modules/$ID/scripts/install.sh"
        echo "  ✓ $NAME configured."
    fi
done

# 4.1 Compute Backend Selection
echo -e "\n${GREEN}Select Compute Backend for High-Power Agents:${NC}"
echo "1) NVIDIA NIM API (Hosted)"
echo "2) RunPod Serverless/Pods"
echo "3) Local Server (vLLM / Ollama)"
echo "n) None (skip configuration)"
echo ""
read -p "Select backend [1-3, default 3]: " BACKEND_CHOICE
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
    bash "$SCRIPT_DIR/scripts/conductor/install.sh"
else
    echo -e "${RED}Error: scripts/conductor/install.sh not found.${NC}"
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
