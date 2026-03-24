#!/usr/bin/env bash
# Add AI Agent aliases to shell configuration
# This script adds qwen and gemini aliases that use agent-wrapper.sh for hcom registration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

if [ -z "$SHELL_CONFIG" ]; then
    echo -e "${RED}Error: Could not detect shell config file${NC}"
    echo "Please manually add the aliases to your shell config."
    exit 1
fi

echo -e "${BLUE}Adding AI agent aliases to $SHELL_CONFIG...${NC}"

# Check if aliases already exist
if grep -q "alias qwen=" "$SHELL_CONFIG" 2>/dev/null && grep -q "alias gemini=" "$SHELL_CONFIG" 2>/dev/null; then
    echo -e "${YELLOW}AI agent aliases already present${NC}"
else
    cat >> "$SHELL_CONFIG" << 'ALIAS_EOF'

# AI Agent Wrappers (with hcom registration)
export SCRIPTS_DIR="$HOME/.hcom/scripts"
alias qwen='bash "$SCRIPTS_DIR/agent-wrapper.sh" qwen'
alias gemini='bash "$SCRIPTS_DIR/agent-wrapper.sh" gemini'
ALIAS_EOF
    echo -e "${GREEN}✓ Aliases added to $SHELL_CONFIG${NC}"
fi

# Also ensure SCRIPTS_DIR is set in current session
export SCRIPTS_DIR="$HOME/.hcom/scripts"

echo ""
echo -e "${BLUE}Aliases added! To use them now, run:${NC}"
echo -e "  source $SHELL_CONFIG"
echo ""
echo -e "${YELLOW}Available commands:${NC}"
echo -e "  ${GREEN}qwen${NC}     - Launch Qwen with hcom registration"
echo -e "  ${GREEN}gemini${NC}   - Launch Gemini with hcom registration"
