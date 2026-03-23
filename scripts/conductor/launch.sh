#!/bin/bash
# Global Conductor Agent Launcher
# Universal launcher for Conductor agent with hcom integration
# Works with any project - project is auto-detected or configurable

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

hcom start --as "$AGENT_NAME" 2>/dev/null || true
hcom events sub --thread "$THREAD_NAME" 2>/dev/null || true

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

case $MODEL in
    qwen)
        echo -e "${GREEN}Launching Qwen CLI...${NC}"
        TMP_SP=$(mktemp /tmp/qwen-sp-XXXXXX.md)
        echo "Conductor Agent. Context: $CONTEXT_FILE" > "$TMP_SP"
        export QWEN_SYSTEM_MD="$TMP_SP"
        qwen --model qwen-max --working-dir "$PROJECT_DIR" "$@"
        rm -f "$TMP_SP"
        ;;
    gemini)
        echo -e "${GREEN}Launching Gemini CLI...${NC}"
        TMP_SP=$(mktemp /tmp/gemini-sp-XXXXXX.md)
        echo "Conductor Agent. Context: $CONTEXT_FILE" > "$TMP_SP"
        export GEMINI_SYSTEM_MD="$TMP_SP"
        gemini --model gemini-3.0 --working-dir "$PROJECT_DIR" "$@"
        rm -f "$TMP_SP"
        ;;
esac

rm -f "$CONTEXT_FILE"
echo -e "${GREEN}Session ended${NC}"
