#!/usr/bin/env bash
# Generic Agent Wrapper
# Consolidates hcom registration and heartbeat

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

TOOL="$1"
shift

# Default models
case "$TOOL" in
    gemini)   DEFAULT_MODEL="gemini-3.0" ;;
    qwen)     DEFAULT_MODEL="qwen3-next-80b-a3b-instruct" ;;
    claude)   DEFAULT_MODEL="claude-3-5-sonnet" ;;
    deepseek) DEFAULT_MODEL="deepseek-v3" ;;
    nemo)     DEFAULT_MODEL="nvidia/llama-3.1-nemotron-70b-instruct" ;;
    vllm)     DEFAULT_MODEL="DeepSeek-Code" ;;
    *)        DEFAULT_MODEL="" ;;
esac

# Register with hcom
register_hcom "$TOOL"
start_heartbeat

# vLLM specific config for ELC
if [ "$TOOL" == "vllm" ]; then
    export USE_CUSTOM_LLM=true
    export CUSTOM_LLM_PROVIDER="openai"
    export CUSTOM_LLM_ENDPOINT="${VLLM_BASE_URL:-http://192.168.0.193:8000/v1}"
    export CUSTOM_LLM_API_KEY="${VLLM_API_KEY:-no-key}"
fi

# Parse arguments
VALID_ARGS=()
MODEL_SET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name) shift 2 ;;
        -m|--model)
            MODEL_SET=true
            VALID_ARGS+=("--model" "$2")
            [ "$TOOL" == "vllm" ] && export CUSTOM_LLM_MODEL_NAME="$2"
            shift 2
            ;;
        *) VALID_ARGS+=("$1") ; shift ;;
    esac
done

if [ "$MODEL_SET" = false ] && [ -n "$DEFAULT_MODEL" ]; then
    VALID_ARGS+=("--model" "$DEFAULT_MODEL")
    [ "$TOOL" == "vllm" ] && export CUSTOM_LLM_MODEL_NAME="$DEFAULT_MODEL"
fi

# Execution
case "$TOOL" in
    vllm) elc "${VALID_ARGS[@]}" ;;
    nemo) 
        if [[ -f "$SCRIPT_DIR/nemo-cli.py" ]]; then
            python3 "$SCRIPT_DIR/nemo-cli.py" "${VALID_ARGS[@]}"
        else
            exec python3 "$HOME/.hcom/scripts/nemo-cli.py" "${VALID_ARGS[@]}"
        fi
        ;;
    *) "$TOOL" "${VALID_ARGS[@]}" ;;
esac
