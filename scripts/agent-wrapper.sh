#!/usr/bin/env bash
# Generic Agent Wrapper
# Consolidates hcom registration, heartbeat, and atari_agent MCP

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

# 2. Register with hcom
register_hcom "$TOOL"
start_heartbeat

# 3. atari_agent MCP Configuration
# Point to the master branch version in Atari-LX project
PROJECT_ROOT=$(detect_project_root)
ATARI_LX_DIR="$(dirname "$PROJECT_ROOT")/Atari-LX"
ATARI_AGENT_DIR="$ATARI_LX_DIR/atari_agent"

if [ -d "$ATARI_AGENT_DIR" ]; then
    # Inject MCP server into environment/args if supported by the tool
    # For gemini-cli and elc, we use the --mcp-server flag pattern if available,
    # but most often they read from settings.json. 
    # Here we ensure the PYTHONPATH includes it for any python-based tools.
    export PYTHONPATH="$ATARI_AGENT_DIR:${PYTHONPATH:-}"
fi

# 4. vLLM specific config for ELC
if [ "$TOOL" == "vllm" ]; then
    export USE_CUSTOM_LLM=true
    export CUSTOM_LLM_PROVIDER="openai"
    export CUSTOM_LLM_ENDPOINT="${VLLM_BASE_URL:-http://192.168.0.193:8000/v1}"
    export CUSTOM_LLM_API_KEY="${VLLM_API_KEY:-no-key}"
fi

# 5. Argument Parsing
VALID_ARGS=()
MODEL_SET=false
SYSTEM_PROMPT_SET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name) shift 2 ;;
        -m|--model)
            MODEL_SET=true
            VALID_ARGS+=("--model" "$2")
            [ "$TOOL" == "vllm" ] && export CUSTOM_LLM_MODEL_NAME="$2"
            shift 2
            ;;
        --system-prompt)
            SYSTEM_PROMPT_SET=true
            VALID_ARGS+=("--system-prompt" "$2")
            shift 2
            ;;
        *) VALID_ARGS+=("$1") ; shift ;;
    esac
done

# Set default model if not specified
if [ "$MODEL_SET" = false ] && [ -n "$DEFAULT_MODEL" ]; then
    VALID_ARGS+=("--model" "$DEFAULT_MODEL")
    [ "$TOOL" == "vllm" ] && export CUSTOM_LLM_MODEL_NAME="$DEFAULT_MODEL"
fi

# Inject Role-Specific System Prompt if not explicitly provided
if [ "$SYSTEM_PROMPT_SET" = false ] && [ -f "$ROLE_PROMPT" ]; then
    VALID_ARGS+=("--system-prompt" "$(cat "$ROLE_PROMPT")")
fi

# 6. Execution
case "$TOOL" in
    vllm) exec elc "${VALID_ARGS[@]}" ;;
    *)    exec "$TOOL" "${VALID_ARGS[@]}" ;;
esac
