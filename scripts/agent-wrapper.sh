#!/usr/bin/env bash
# Generic Agent Wrapper v2.2
# Consolidates hcom registration, heartbeat, and atari_agent MCP
# Now includes automatic restart to maintain persistent presence

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

TOOL="$1"
shift

# 1. Configuration & Role Determination
case "$TOOL" in
    gemini)
        DEFAULT_MODEL="gemini-3.0"
        ROLE_PROMPT="$SCRIPT_DIR/../system-prompts/gemini.md"
        ;;
    qwen)
        DEFAULT_MODEL="qwen3-next-80b-a3b-instruct"
        ROLE_PROMPT="$SCRIPT_DIR/../system-prompts/qwen.md"
        ;;
    deepseek)
        DEFAULT_MODEL="deepseek-v3"
        ROLE_PROMPT="$SCRIPT_DIR/../system-prompts/deepseek.md"
        ;;
    vllm)
        DEFAULT_MODEL="DeepSeek-Code"
        ROLE_PROMPT="$SCRIPT_DIR/../system-prompts/deepseek.md"
        ;;
    *)
        DEFAULT_MODEL=""
        ROLE_PROMPT=""
        ;;
esac

# Check if tool is available before registering
CMD=""
case "$TOOL" in
    gemini)
        if has_command gemini-cli; then CMD="gemini-cli";
        elif has_command gemini; then CMD="gemini"; fi
        ;;
    qwen)
        if has_command qwen-code; then CMD="qwen-code";
        elif has_command qwen; then CMD="qwen";
        elif has_command qwen-cli; then CMD="qwen-cli"; fi
        ;;
    vllm) CMD="elc" ;;
    nemo) CMD="python3 $SCRIPT_DIR/nemo-cli.py" ;;
    deepseek)
        if has_command deepseek-cli; then CMD="deepseek-cli";
        else CMD="deepseek"; fi
        ;;
    *) CMD="$TOOL" ;;
esac

if [ -z "$CMD" ] && [ "$TOOL" != "nemo" ]; then
    echo "Error: Tool $TOOL not found. Please run ./install.sh"
    exit 1
fi

# 2. Module-Specific Configuration (e.g., Atari 8-Bit)
if [[ "${ENABLE_ATARI_8BIT:-false}" == "true" ]]; then
    PROJECT_ROOT=$(detect_project_root 2>/dev/null || dirname "$SCRIPT_DIR")
    ATARI_8BIT_DIR="$(dirname "$PROJECT_ROOT")/Atari-LX"
    ATARI_AGENT_DIR="$ATARI_8BIT_DIR/atari_agent"

    if [ -d "$ATARI_AGENT_DIR" ]; then
        # Inject MCP server into environment/args if supported by the tool
        export PYTHONPATH="$ATARI_AGENT_DIR:${PYTHONPATH:-}"
    fi
fi

# 2.1 Core Dev MCP Configuration
CORE_DEV_MCP="$PROJECT_ROOT/mcp/core-dev/server.py"
if [ -f "$CORE_DEV_MCP" ]; then
    # Some tools might need explicit flags, for now we just ensure it's findable
    # If the LLM CLI supports direct MCP injection via env vars
    export CORE_DEV_MCP_PATH="$CORE_DEV_MCP"
fi

# 3. vLLM specific config for ELC
if [ "$TOOL" == "vllm" ]; then
    export USE_CUSTOM_LLM=true
    export CUSTOM_LLM_PROVIDER="openai"
    export CUSTOM_LLM_ENDPOINT="${VLLM_BASE_URL:-http://192.168.0.193:8000/v1}"
    export CUSTOM_LLM_API_KEY="${VLLM_API_KEY:-no-key}"
fi

# 4. Argument Parsing
VALID_ARGS=()
MODEL_SET=false
SYSTEM_PROMPT_SET=false
SYSTEM_PROMPT_CONTENT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name) 
            export HCOM_NAME="$2"
            shift 2 
            ;;
        -m|--model)
            MODEL_SET=true
            VALID_ARGS+=("--model" "$2")
            [ "$TOOL" == "vllm" ] && export CUSTOM_LLM_MODEL_NAME="$2"
            shift 2
            ;;
        --system-prompt)
            SYSTEM_PROMPT_SET=true
            SYSTEM_PROMPT_CONTENT="$2"
            shift 2
            ;;
        *) VALID_ARGS+=("$1") ; shift ;;
    esac
done

# 5. Register with hcom and start heartbeat
# This performs initial registration (uses HCOM_NAME if set by --name or environment)
register_hcom "$TOOL"

# Start heartbeat to keep agent status fresh in hcom TUI
# This prevents the "exit:timeout" cycling issue
start_heartbeat "$TOOL"

CLEANUP_FILES=()
cleanup() {
    # 1. Kill background heartbeat if it exists
    if [ -n "${HEARTBEAT_PID:-}" ]; then
        kill "$HEARTBEAT_PID" 2>/dev/null || true
    fi

    # 2. Fix for Bash 3.2 on macOS: handle empty arrays with set -u
    for f in ${CLEANUP_FILES[@]+"${CLEANUP_FILES[@]}"}; do rm -f "$f" 2>/dev/null || true; done
    
    # 3. Notify hcom of exit if possible
    if [ -n "${HCOM_NAME:-}" ]; then
        hcom stop --name "$HCOM_NAME" > /dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

# Set default model if not specified
if [ "$MODEL_SET" = false ] && [ -n "$DEFAULT_MODEL" ]; then
    VALID_ARGS+=("--model" "$DEFAULT_MODEL")
    [ "$TOOL" == "vllm" ] && export CUSTOM_LLM_MODEL_NAME="$DEFAULT_MODEL"
fi

# Inject Role-Specific System Prompt if not explicitly provided
if [ "$SYSTEM_PROMPT_SET" = false ] && [ -f "$ROLE_PROMPT" ]; then
    SYSTEM_PROMPT_CONTENT="$(cat "$ROLE_PROMPT")"
    SYSTEM_PROMPT_SET=true
fi

# Append Conductor context if provided (from launch.sh)
if [ -n "${QWEN_CONTEXT_FILE:-}" ] && [ -f "$QWEN_CONTEXT_FILE" ]; then
    SYSTEM_PROMPT_CONTENT="$SYSTEM_PROMPT_CONTENT

$(cat "$QWEN_CONTEXT_FILE")"
    SYSTEM_PROMPT_SET=true
elif [ -n "${GEMINI_CONTEXT_FILE:-}" ] && [ -f "$GEMINI_CONTEXT_FILE" ]; then
    SYSTEM_PROMPT_CONTENT="$SYSTEM_PROMPT_CONTENT

$(cat "$GEMINI_CONTEXT_FILE")"
    SYSTEM_PROMPT_SET=true
fi

# 6. Execution
# Apply system prompt via environment variable for tools that support it
if [ "$SYSTEM_PROMPT_SET" = true ]; then
    case "$TOOL" in
        gemini)
            # Use XXXXXX at the end for macOS compatibility
            TMP_SP=$(mktemp /tmp/gemini-sp-XXXXXX)
            mv "$TMP_SP" "$TMP_SP.md"
            TMP_SP="$TMP_SP.md"
            echo "$SYSTEM_PROMPT_CONTENT" > "$TMP_SP"
            export GEMINI_SYSTEM_MD="$TMP_SP"
            CLEANUP_FILES+=("$TMP_SP")
            ;;
        qwen)
            # Use XXXXXX at the end for macOS compatibility
            TMP_SP=$(mktemp /tmp/qwen-sp-XXXXXX)
            mv "$TMP_SP" "$TMP_SP.md"
            TMP_SP="$TMP_SP.md"
            echo "$SYSTEM_PROMPT_CONTENT" > "$TMP_SP"
            export QWEN_SYSTEM_MD="$TMP_SP"
            CLEANUP_FILES+=("$TMP_SP")
            ;;
        nemo|deepseek|claude|vllm)
            # These might support --system-prompt or we pass it through
            VALID_ARGS+=("--system-prompt" "$SYSTEM_PROMPT_CONTENT")
            ;;
        *)
            # Fallback
            VALID_ARGS+=("--system-prompt" "$SYSTEM_PROMPT_CONTENT")
            ;;
    esac
fi

# Run the command with automatic restart to maintain persistent presence
# This ensures the agent stays registered with hcom even if the LLM CLI exits
run_agent() {
    if [[ "$CMD" == *" "* ]]; then
        eval "$CMD" '"${VALID_ARGS[@]}"'
    else
        "$CMD" "${VALID_ARGS[@]}"
    fi
}

# Main loop: restart agent if it exits (but not on normal exit)
RESTART_COUNT=0
MAX_RESTARTS=10
RESTART_DELAY=10

while true; do
    echo "[$(date '+%H:%M:%S')] Starting $TOOL agent (attempt $((RESTART_COUNT + 1)))..."
    
    # Run the agent command
    set +e  # Don't exit on error - we want to restart
    run_agent
    EXIT_CODE=$?
    set -e
    
    echo "[$(date '+%H:%M:%S')] $TOOL agent exited with code $EXIT_CODE"
    
    # Check if we should restart
    if [ $RESTART_COUNT -ge $MAX_RESTARTS ]; then
        echo "[$(date '+%H:%M:%S')] Max restarts ($MAX_RESTARTS) reached, exiting"
        exit $EXIT_CODE
    fi
    
    # Increment restart counter and wait before restarting
    RESTART_COUNT=$((RESTART_COUNT + 1))
    echo "[$(date '+%H:%M:%S')] Restarting in ${RESTART_DELAY}s... (Ctrl+C to stop)"
    sleep $RESTART_DELAY
done
