#!/bin/bash
# Global Conductor Agent Installation Script
# Installs conductor utilities and shell aliases

set -e

CONDUCTOR_HOME="$HOME/.hcom/scripts/conductor"
BIN_DIR="$HOME/.local/bin"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Conductor Agent Installer           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Verify installation
if [ ! -f "$CONDUCTOR_HOME/launch.sh" ]; then
    echo -e "${RED}Error: Conductor launcher not found${NC}"
    exit 1
fi

# Create bin directory
mkdir -p "$BIN_DIR"

# Create symlinks
echo -e "${GREEN}Creating symlinks in $BIN_DIR...${NC}"
ln -sf "$CONDUCTOR_HOME/launch.sh" "$BIN_DIR/conductor"
ln -sf "$CONDUCTOR_HOME/status.sh" "$BIN_DIR/conductor-status"
echo -e "  ✓ $BIN_DIR/conductor"
echo -e "  ✓ $BIN_DIR/conductor-status"
echo ""

# Add to PATH if not already
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    echo -e "${YELLOW}Adding $BIN_DIR to PATH in ~/.bashrc...${NC}"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi

# Add aliases
if ! grep -q "alias conductor=" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'ALIAS_EOF'

# Conductor Agent
export CONDUCTOR_HOME="$HOME/.hcom/scripts/conductor"
alias conductor-status='conductor-status'
ALIAS_EOF
    echo -e "  ✓ Aliases added to ~/.bashrc"
else
    echo -e "  ✓ Aliases already present"
fi

# Source bashrc
source ~/.bashrc 2>/dev/null || true

echo ""
echo -e "${BLUE}Installation complete!${NC}"
echo ""
echo -e "${YELLOW}Commands available:${NC}"
echo -e "  ${GREEN}conductor${NC}         - Launch conductor (auto-detect project)"
echo -e "  ${GREEN}conductor-status${NC}  - Check status"
echo ""
echo -e "${YELLOW}Usage:${NC}"
echo -e "  ${GREEN}conductor${NC}                    # Auto-detect project"
echo -e "  ${GREEN}conductor -p ~/project${NC}       # Specify project"
echo -e "  ${GREEN}conductor qwen${NC}               # Use Qwen"
echo -e "  ${GREEN}conductor-status${NC}             # Check status"
echo ""
echo -e "${GREEN}✓ Ready to use!${NC}"
