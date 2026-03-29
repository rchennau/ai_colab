#!/usr/bin/env bash
# ai-colab Debug Mode with KB/RAG Integration
# Provides a dedicated LLM CLI session with project context for troubleshooting

set -euo pipefail

# Find script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Project detection
PROJECT_ROOT=$(detect_project_root 2>/dev/null || echo "$SCRIPT_DIR/..")
cd "$PROJECT_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
KB_FILE="$PROJECT_ROOT/conductor/knowledge_base_map.md"
RAG_DIR="$PROJECT_ROOT/.ai-colab/rag"
PRODUCT_FILE="$PROJECT_ROOT/conductor/product.md"
TECH_STACK_FILE="$PROJECT_ROOT/conductor/tech-stack.md"

# Parse arguments
AGENT="${1:-}"
if [[ -z "$AGENT" ]]; then
    echo -e "${RED}Usage: debug-mode.sh <agent>${NC}"
    echo -e "Agents: qwen, gemini, claude, deepseek"
    exit 1
fi

# Map agent names to commands
case "$AGENT" in
    qwen) AGENT_CMD="qwen-code" ;;
    gemini) AGENT_CMD="gemini-cli" ;;
    claude) AGENT_CMD="claude-code" ;;
    deepseek) AGENT_CMD="deepseek-cli" ;;
    *) echo -e "${RED}Unknown agent: $AGENT${NC}"; exit 1 ;;
esac

# Check if agent is installed
if ! command -v "$AGENT_CMD" &> /dev/null; then
    echo -e "${RED}Error: $AGENT_CMD is not installed${NC}"
    echo -e "Run ./install.sh to install LLM CLI tools"
    exit 1
fi

# Build context prompt
build_context_prompt() {
    local context=""

    # Product definition
    if [[ -f "$PRODUCT_FILE" ]]; then
        context+="=== PRODUCT DEFINITION ===\n"
        context+="$(head -50 "$PRODUCT_FILE")\n\n"
    fi

    # Tech stack
    if [[ -f "$TECH_STACK_FILE" ]]; then
        context+="=== TECH STACK ===\n"
        context+="$(head -30 "$TECH_STACK_FILE")\n\n"
    fi

    # Knowledge base summary
    if [[ -f "$KB_FILE" ]]; then
        context+="=== KNOWLEDGE BASE ===\n"
        context+="$(head -40 "$KB_FILE")\n\n"
    fi

    # RAG status
    if [[ -d "$RAG_DIR" ]]; then
        local doc_count=$(find "$RAG_DIR" -name "*.json" 2>/dev/null | wc -l)
        context+="=== RAG INDEX ===\n"
        context+="Indexed documents: $doc_count\n"
        context+="Location: $RAG_DIR\n\n"
    fi

    echo -e "$context"
}

# Create temporary context file
CONTEXT_FILE=$(mktemp /tmp/ai-colab-debug-context-XXXXXX.md)
trap "rm -f $CONTEXT_FILE" EXIT

cat > "$CONTEXT_FILE" << 'CONTEXT_HEADER'
# ai-colab Debug Session Context

You are an AI assistant helping debug and troubleshoot the ai-colab project.
This is a dedicated debug session with access to project knowledge.

## Available Commands
- `!kb <query>` - Search the architectural knowledge base
- `!rag <query>` - Search indexed documents via RAG
- `!status` - Get project status from conductor
- `!build` - Run build and tests
- `!files <pattern>` - Search project files

## Project Information
CONTEXT_HEADER

# Append dynamic context
build_context_prompt >> "$CONTEXT_FILE"

# Add instructions
cat >> "$CONTEXT_FILE" << 'CONTEXT_FOOTER'

## Debug Session Guidelines
1. Always check the KB first for architectural decisions
2. Use RAG to search implementation details in indexed files
3. When suggesting fixes, provide complete code changes
4. Reference specific files and line numbers when possible
5. Consider the existing architecture before proposing changes

You are now ready to help debug ai-colab. The user will describe their issue.
CONTEXT_FOOTER

# Display startup banner
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           ai-colab Debug Mode                            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Agent:${NC} $AGENT_CMD"
echo -e "${GREEN}Project:${NC} $PROJECT_ROOT"
echo ""

# Check RAG availability
if [[ -d "$RAG_DIR" ]] && python3 -c "import sentence_transformers" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} RAG system available"
    RAG_AVAILABLE=true
else
    echo -e "${YELLOW}○${NC} RAG not available (install with: pip install sentence-transformers)"
    RAG_AVAILABLE=false
fi

# Check KB
if [[ -f "$KB_FILE" ]]; then
    echo -e "${GREEN}✓${NC} Knowledge base loaded ($(wc -l < "$KB_FILE") lines)"
else
    echo -e "${YELLOW}○${NC} Knowledge base not found"
fi

echo ""
echo -e "${YELLOW}Context file created: $CONTEXT_FILE${NC}"
echo -e "${BLUE}Starting $AGENT_CMD with project context...${NC}"
echo ""
echo -e "${CYAN}Tip: Reference the context file with: @$(basename "$CONTEXT_FILE")${NC}"
echo ""

# Start the agent with context
# Different agents have different ways to provide context
case "$AGENT_CMD" in
    qwen-code)
        # Qwen supports --context flag
        exec qwen-code --context "$CONTEXT_FILE"
        ;;
    gemini-cli)
        # Gemini can read files via @ syntax
        exec gemini-cli
        ;;
    claude-code)
        # Claude can read files via @ syntax
        exec claude-code
        ;;
    deepseek-cli)
        # DeepSeek reads from stdin or files
        exec deepseek-cli
        ;;
esac
