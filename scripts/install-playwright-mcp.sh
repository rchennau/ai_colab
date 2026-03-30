#!/usr/bin/env bash
# Install Playwright MCP Server for ai-colab
# Run this script to set up browser automation for Claude

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║     ai-colab Playwright MCP Installer                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Check for npx
if ! command -v npx &> /dev/null; then
    echo "❌ npx not found. Please install Node.js first:"
    echo ""
    echo "  # Using conda:"
    echo "  conda install -c conda-forge nodejs"
    echo ""
    echo "  # Or from nodejs.org:"
    echo "  https://nodejs.org/"
    echo ""
    exit 1
fi

echo "✓ npx found: $(which npx)"
echo ""

# Check if already installed
if npx --yes @playwright/mcp@latest --help >/dev/null 2>&1; then
    echo "✓ Playwright MCP already installed"
else
    echo "Installing Playwright MCP..."
    echo ""
    echo "⚠ This may take several minutes (downloading Chromium browser)"
    echo ""
    
    # Install with progress
    npx --yes @playwright/mcp@latest --help >/dev/null 2>&1 && echo "✓ Playwright MCP installed" || {
        echo ""
        echo "❌ Installation failed. Try manual installation:"
        echo ""
        echo "  npx --yes @playwright/mcp@latest"
        echo ""
        exit 1
    }
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Installation Complete!"
echo ""
echo "Next Steps:"
echo ""
echo "1. Add to claude_desktop_config.json:"
echo ""
echo "{"
echo "  \"mcpServers\": {"
echo "    \"playwright\": {"
echo "      \"command\": \"npx\","
echo "      \"args\": [\"-y\", \"@playwright/mcp@latest\"],"
echo "      \"transport\": \"stdio\""
echo "    }"
echo "  }"
echo "}"
echo ""
echo "2. Restart Claude Desktop"
echo ""
echo "3. Ask Claude to test the WebUI:"
echo "   'Test the ai-colab WebUI at http://localhost:8080'"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""

# Offer to configure Claude Desktop
read -p "Configure Claude Desktop automatically? [y/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Detect OS and configure
    if [[ "$OSTYPE" == "darwin"* ]]; then
        CLAUDE_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        CLAUDE_CONFIG="$HOME/.config/Claude/claude_desktop_config.json"
    else
        echo "⚠ Unknown OS. Please configure manually."
        exit 0
    fi
    
    # Create directory if needed
    mkdir -p "$(dirname "$CLAUDE_CONFIG")"
    
    # Backup existing config
    if [[ -f "$CLAUDE_CONFIG" ]]; then
        cp "$CLAUDE_CONFIG" "${CLAUDE_CONFIG}.bak"
        echo "✓ Backed up existing config"
    fi
    
    # Add Playwright MCP config
    if command -v jq &> /dev/null; then
        # Use jq for proper JSON manipulation
        if [[ -f "$CLAUDE_CONFIG" ]]; then
            jq '.mcpServers.playwright = {"command": "npx", "args": ["-y", "@playwright/mcp@latest"], "transport": "stdio"}' "$CLAUDE_CONFIG" > "${CLAUDE_CONFIG}.tmp" && \
            mv "${CLAUDE_CONFIG}.tmp" "$CLAUDE_CONFIG"
        else
            echo '{"mcpServers": {"playwright": {"command": "npx", "args": ["-y", "@playwright/mcp@latest"], "transport": "stdio"}}}' > "$CLAUDE_CONFIG"
        fi
    else
        # Fallback: simple echo (may not preserve formatting)
        cat > "$CLAUDE_CONFIG" << 'EOF'
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"],
      "transport": "stdio"
    }
  }
}
EOF
    fi
    
    echo "✓ Claude Desktop configured"
    echo ""
    echo "Restart Claude Desktop to apply changes."
fi
