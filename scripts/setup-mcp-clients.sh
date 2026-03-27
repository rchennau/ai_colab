#!/bin/bash
#
# MCP Client Setup Script
# Configures LLM-CLIs to use the ai-colab MCP server
#
# Usage: ./scripts/setup-mcp-clients.sh [--gemini] [--qwen] [--claude] [--all]
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

print_success() {
    echo -e "${GREEN}SUCCESS:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

# Get user's home directory
HOME_DIR="$HOME"

# Configuration templates
GEMINI_CONFIG_DIR="$HOME_DIR/.gemini-cli"
QWEN_CONFIG_DIR="$HOME_DIR/.qwen"
CLAUDE_CONFIG_DIR="$HOME_DIR/.claude"

# Setup gemini-cli
setup_gemini() {
    print_info "Setting up gemini-cli MCP integration..."
    
    # Create config directory if needed
    if [[ ! -d "$GEMINI_CONFIG_DIR" ]]; then
        mkdir -p "$GEMINI_CONFIG_DIR"
        print_info "Created $GEMINI_CONFIG_DIR"
    fi
    
    # Check if config exists
    CONFIG_FILE="$GEMINI_CONFIG_DIR/config.toml"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        # Check if MCP section exists
        if grep -q '\[mcp\]' "$CONFIG_FILE" 2>/dev/null; then
            print_warning "MCP configuration already exists in $CONFIG_FILE"
            read -p "Overwrite? (y/N): " confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                print_info "Skipping gemini-cli setup"
                return 0
            fi
        fi
        
        # Backup existing config
        cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d-%H%M%S)"
        print_info "Backed up existing config"
    fi
    
    # Create config with MCP section
    cat >> "$CONFIG_FILE" << 'EOF'

# ai-colab MCP Server Integration
[mcp]
enabled = true

[mcp.servers.ai-colab]
name = "ai-colab"
command = "python"
args = ["-m", "mcp.ai_colab_server"]
transport = "stdio"
working_directory = "{{PROJECT_ROOT}}"
timeout = 30000
EOF
    
    # Replace placeholder with actual path
    sed -i.bak "s|{{PROJECT_ROOT}}|$PROJECT_ROOT|g" "$CONFIG_FILE"
    rm -f "$CONFIG_FILE.bak"
    
    print_success "gemini-cli configured successfully!"
    print_info "Config file: $CONFIG_FILE"
}

# Setup qwen-code
setup_qwen() {
    print_info "Setting up qwen-code MCP integration..."
    
    # Create config directory if needed
    if [[ ! -d "$QWEN_CONFIG_DIR" ]]; then
        mkdir -p "$QWEN_CONFIG_DIR"
        print_info "Created $QWEN_CONFIG_DIR"
    fi
    
    # Check if config exists
    CONFIG_FILE="$QWEN_CONFIG_DIR/config.toml"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        # Check if MCP section exists
        if grep -q '\[mcp\]' "$CONFIG_FILE" 2>/dev/null; then
            print_warning "MCP configuration already exists in $CONFIG_FILE"
            read -p "Overwrite? (y/N): " confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                print_info "Skipping qwen-code setup"
                return 0
            fi
        fi
        
        # Backup existing config
        cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d-%H%M%S)"
        print_info "Backed up existing config"
    fi
    
    # Create config with MCP section
    cat >> "$CONFIG_FILE" << 'EOF'

# ai-colab MCP Server Integration
[mcp]
enabled = true

[mcp.servers.ai-colab]
name = "ai-colab"
type = "stdio"
command = "python"
args = ["-m", "mcp.ai_colab_server"]
cwd = "{{PROJECT_ROOT}}"
EOF
    
    # Replace placeholder with actual path
    sed -i.bak "s|{{PROJECT_ROOT}}|$PROJECT_ROOT|g" "$CONFIG_FILE"
    rm -f "$CONFIG_FILE.bak"
    
    print_success "qwen-code configured successfully!"
    print_info "Config file: $CONFIG_FILE"
}

# Setup claude-code
setup_claude() {
    print_info "Setting up claude-code MCP integration..."
    
    # Create config directory if needed
    if [[ ! -d "$CLAUDE_CONFIG_DIR" ]]; then
        mkdir -p "$CLAUDE_CONFIG_DIR"
        print_info "Created $CLAUDE_CONFIG_DIR"
    fi
    
    # Check for settings file
    CONFIG_FILE="$CLAUDE_CONFIG_DIR/settings.json"
    
    # Create settings directory for project-local config
    PROJECT_CLAUDE_DIR="$PROJECT_ROOT/.claude"
    mkdir -p "$PROJECT_CLAUDE_DIR"
    
    # Create settings file
    cat > "$PROJECT_CLAUDE_DIR/settings.local.json" << EOF
{
  "mcpServers": {
    "ai-colab": {
      "command": "python",
      "args": ["-m", "mcp.ai_colab_server"],
      "cwd": "$PROJECT_ROOT",
      "transportType": "stdio"
    }
  }
}
EOF
    
    print_success "claude-code configured successfully!"
    print_info "Project config: $PROJECT_CLAUDE_DIR/settings.local.json"
    print_warning "Note: claude-code uses project-local config. Copy to ~/.claude/ if needed."
}

# Test MCP server
test_mcp() {
    print_info "Testing MCP server..."
    
    # Check if dependencies are installed
    if ! python3 -c "import fastmcp" 2>/dev/null; then
        print_warning "fastmcp not installed. Install with: pip install -r requirements-mcp.txt"
        return 1
    fi
    
    # Test server startup
    cd "$PROJECT_ROOT"
    if timeout 5 python3 -m mcp.ai_colab_server >/dev/null 2>&1; then
        print_success "MCP server test passed!"
    else
        print_warning "MCP server test had issues (may still work with LLM-CLI)"
    fi
}

# Show usage
show_help() {
    cat << EOF
MCP Client Setup Script

Configures LLM-CLIs to use the ai-colab MCP server.

Usage: $0 [options]

Options:
  --gemini     Setup gemini-cli only
  --qwen       Setup qwen-code only
  --claude     Setup claude-code only
  --all        Setup all LLM-CLIs (default)
  --test       Test MCP server only
  --help       Show this help

Examples:
  $0 --all           # Setup all clients
  $0 --gemini        # Setup gemini-cli only
  $0 --test          # Test MCP server

EOF
}

# Main
main() {
    local setup_gemini_flag=false
    local setup_qwen_flag=false
    local setup_claude_flag=false
    local test_only_flag=false
    
    # Parse arguments
    if [[ $# -eq 0 ]]; then
        setup_gemini_flag=true
        setup_qwen_flag=true
        setup_claude_flag=true
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --gemini)
                setup_gemini_flag=true
                shift
                ;;
            --qwen)
                setup_qwen_flag=true
                shift
                ;;
            --claude)
                setup_claude_flag=true
                shift
                ;;
            --all)
                setup_gemini_flag=true
                setup_qwen_flag=true
                setup_claude_flag=true
                shift
                ;;
            --test)
                test_only_flag=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Test MCP server
    if [[ "$test_only_flag" == "true" ]]; then
        test_mcp
        exit $?
    fi
    
    print_info "Setting up MCP clients for ai-colab"
    print_info "Project root: $PROJECT_ROOT"
    echo ""
    
    # Run setups
    if [[ "$setup_gemini_flag" == "true" ]]; then
        setup_gemini
        echo ""
    fi
    
    if [[ "$setup_qwen_flag" == "true" ]]; then
        setup_qwen
        echo ""
    fi
    
    if [[ "$setup_claude_flag" == "true" ]]; then
        setup_claude
        echo ""
    fi
    
    # Test
    print_info "Running MCP server test..."
    test_mcp
    
    echo ""
    print_success "MCP client setup complete!"
    print_info ""
    print_info "Next steps:"
    print_info "1. Restart your LLM-CLI"
    print_info "2. Try: '@ai-colab What is the project status?'"
    print_info ""
}

main "$@"
