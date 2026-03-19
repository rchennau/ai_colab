#!/usr/bin/env bash
# Global Conductor Agent Installation Script
# Installs conductor utilities and shell aliases

set -e

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils.sh"

CONDUCTOR_HOME="$HOME/.hcom/scripts/conductor"
BIN_DIR="$HOME/.local/bin"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Conductor Agent Installer           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check for hcom
check_hcom || true

# Verify source files exist in current project context
if [ ! -f "$SCRIPT_DIR/launch.sh" ]; then
    echo -e "${RED}Error: Conductor launcher not found in $SCRIPT_DIR${NC}"
    exit 1
fi

# Create conductor home if it doesn't exist
mkdir -p "$CONDUCTOR_HOME"
cp "$SCRIPT_DIR/launch.sh" "$CONDUCTOR_HOME/"
cp "$SCRIPT_DIR/status.sh" "$CONDUCTOR_HOME/"
cp "$SCRIPT_DIR/../utils.sh" "$HOME/.hcom/scripts/"

# Create bin directory
mkdir -p "$BIN_DIR"

# Create symlinks
echo -e "${GREEN}Creating symlinks in $BIN_DIR...${NC}"
ln -sf "$CONDUCTOR_HOME/launch.sh" "$BIN_DIR/conductor"
ln -sf "$CONDUCTOR_HOME/status.sh" "$BIN_DIR/conductor-status"
echo -e "  ✓ $BIN_DIR/conductor"
echo -e "  ✓ $BIN_DIR/conductor-status"
echo ""

# Determine shell config file
SHELL_CONFIG=""
if [[ "$SHELL" == */zsh ]]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [[ "$SHELL" == */bash ]]; then
    SHELL_CONFIG="$HOME/.bashrc"
    # Also check .bash_profile for macOS
    if [[ "$OSTYPE" == "darwin"* ]] && [ -f "$HOME/.bash_profile" ]; then
        SHELL_CONFIG="$HOME/.bash_profile"
    fi
fi

if [ -n "$SHELL_CONFIG" ]; then
    # Add to PATH if not already
    if ! grep -q "$BIN_DIR" "$SHELL_CONFIG" 2>/dev/null; then
        echo -e "${YELLOW}Adding $BIN_DIR to PATH in $SHELL_CONFIG...${NC}"
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$SHELL_CONFIG"
    fi

    # Add aliases
    if ! grep -q "alias conductor=" "$SHELL_CONFIG" 2>/dev/null; then
        cat >> "$SHELL_CONFIG" << 'ALIAS_EOF'

# Conductor Agent
export CONDUCTOR_HOME="$HOME/.hcom/scripts/conductor"
alias conductor-status='conductor-status'
ALIAS_EOF
        echo -e "  ✓ Aliases added to $SHELL_CONFIG"
    else
        echo -e "  ✓ Aliases already present"
    fi
else
    echo -e "${YELLOW}Warning: Could not detect shell config file (tried .bashrc, .zshrc).${NC}"
    echo -e "Please manually add $BIN_DIR to your PATH."
fi

if [ -n "$SHELL_CONFIG" ] && [ -f "$SHELL_CONFIG" ] && [[ "$SHELL_CONFIG" != *".zshrc" ]]; then
    echo -e "\n${BLUE}Sourcing $SHELL_CONFIG...${NC}"
    source "$SHELL_CONFIG"
fi

# Manually update the current script's PATH to include the new bin directory
export PATH="$BIN_DIR:$PATH"

echo ""
echo -e "${BLUE}Installation complete!${NC}"
echo ""
echo -e "${YELLOW}Commands available:${NC}"
echo -e "  ${GREEN}conductor${NC}         - Launch conductor (global command)"
echo -e "  ${GREEN}conductor-status${NC}  - Check status"
echo ""
echo -e "${GREEN}To launch the full system from this directory, run:${NC}"
echo -e "  ${BLUE}./launch.sh${NC}"
echo ""
echo -e "${GREEN}✓ Ready to use!${NC}"
