#!/bin/bash
# Global Conductor Agent Launcher
# Universal launcher for Conductor agent with hcom integration
# Works with any project - project is auto-detected or configurable
# Uses agent-wrapper.sh for proper hcom registration and heartbeat

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Defaults
MODEL="${1:-gemini}"
PROJECT_DIR=""
AGENT_NAME=""
THREAD_NAME="plan-sync"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_SCRIPT="$SCRIPT_DIR/../agent-wrapper.sh"

show_help() {
    cat << EOF
${BLUE}╔════════════════════════════════════════╗${NC}
${BLUE}║   Global Conductor Agent Launcher     ║${NC}
${BLUE}╚════════════════════════════════════════╝${NC}

${BLUE}Usage:${NC}
  conductor [qwen|gemini] [options]
  conductor -p /path/to/project gemini

${BLUE}Options:${NC}
  -h, --help           Show help
  -p, --project DIR    Project directory (auto-detect)
  -n, --name NAME      Agent name (default: conductor-<model>)
  -t, --thread NAME    hcom thread (default: plan-sync)

${BLUE}Examples:${NC}
  conductor                    # Auto-detect, Gemini
  conductor -p ~/my-project    # Specify project
  conductor qwen -n my-agent   # Qwen with custom name
EOF
}

# Parse args
shift || true
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) show_help; exit 0 ;;
        -p|--project) PROJECT_DIR="$2"; shift 2 ;;
        -n|--name) AGENT_NAME="$2"; shift 2 ;;
        -t|--thread) THREAD_NAME="$2"; shift 2 ;;
        qwen|gemini) MODEL="$1"; shift ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; show_help; exit 1 ;;
    esac
done

# Auto-detect project
detect_project() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [ -f "$dir/conductor/tracks.md" ] || [ -f "$dir/conductor/product.md" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

if [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR=$(detect_project) || {
        echo -e "${RED}Error: No project found${NC}"
        echo -e "${YELLOW}Use -p /path/to/project${NC}"
        exit 1
    }
fi

if [ ! -d "$PROJECT_DIR" ] || [ ! -f "$PROJECT_DIR/conductor/tracks.md" ]; then
    echo -e "${RED}Error: Invalid project: $PROJECT_DIR${NC}"
    exit 1
fi

[ -z "$AGENT_NAME" ] && AGENT_NAME="conductor-${MODEL}"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Global Conductor Agent Launcher     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Project:${NC} $PROJECT_DIR"
echo -e "${GREEN}Model:${NC}   $MODEL"
echo -e "${GREEN}Agent:${NC}   $AGENT_NAME"
echo -e "${GREEN}Thread:${NC}  $THREAD_NAME"

cd "$PROJECT_DIR"

export HCOM_AGENT_NAME="$AGENT_NAME"
export HCOM_PROJECT_DIR="$PROJECT_DIR"
export HCOM_THREAD_NAME="$THREAD_NAME"

# Create context
CONTEXT_FILE=$(mktemp /tmp/conductor-context-XXXXXX)
cat > "$CONTEXT_FILE" << CTXEOF
Conductor Agent for: $PROJECT_DIR
Agent: $AGENT_NAME | Thread: $THREAD_NAME

Responsibilities:
1. Monitor conductor/tracks.md
2. Status reports every 30 min
3. Coordinate via hcom
4. Report blockers

Key files:
- conductor/tracks.md
- conductor/product.md
CTXEOF

# Use agent-wrapper.sh for proper hcom registration and heartbeat
if [ ! -f "$WRAPPER_SCRIPT" ]; then
    echo -e "${RED}Error: agent-wrapper.sh not found at $WRAPPER_SCRIPT${NC}"
    exit 1
fi

case $MODEL in
    qwen)
        echo -e "${GREEN}Launching Qwen CLI via agent-wrapper...${NC}"
        export QWEN_CONTEXT_FILE="$CONTEXT_FILE"
        exec bash "$WRAPPER_SCRIPT" qwen --name "$AGENT_NAME" "$@"
        ;;
    gemini)
        echo -e "${GREEN}Launching Gemini CLI via agent-wrapper...${NC}"
        export GEMINI_CONTEXT_FILE="$CONTEXT_FILE"
        exec bash "$WRAPPER_SCRIPT" gemini --name "$AGENT_NAME" "$@"
        ;;
esac

# Cleanup (only reached on error)
rm -f "$CONTEXT_FILE"
echo -e "${GREEN}Session ended${NC}"
