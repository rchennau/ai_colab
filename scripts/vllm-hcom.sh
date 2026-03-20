#!/usr/bin/env bash
# vLLM CLI Wrapper with hcom Integration (via easy-llm-cli)
# Launches a remote vLLM agent specialized for Atari 800XL

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# --- easy-llm-cli (ELC) Configuration ---
export USE_CUSTOM_LLM=true
export CUSTOM_LLM_PROVIDER="openai"
export CUSTOM_LLM_ENDPOINT="${VLLM_BASE_URL:-http://192.168.0.193:8000/v1}"
export CUSTOM_LLM_API_KEY="${VLLM_API_KEY:-no-key}"

if has_command hcom;
 then
    # Register with hcom to enable messaging
    # Use underscore instead of hyphen for hcom 0.7.5 compatibility
    AGENT_NAME="${HCOM_NAME:-vllm_$$}"
    export HCOM_NAME="$AGENT_NAME"
    
    hcom start --as "$HCOM_NAME" > /dev/null 2>&1 || true
    hcom listen --name "$HCOM_NAME" --timeout 1 > /dev/null 2>&1 || true
    
    # Start background heartbeat to prevent stale status
    (while true; do 
        hcom listen --name "$HCOM_NAME" --timeout 60 > /dev/null 2>&1 || sleep 60
    done) &
    HB_PID=$!
    trap "kill $HB_PID 2>/dev/null || true" EXIT
fi

# Default model (vLLM expects the model name it was launched with)
DEFAULT_MODEL="DeepSeek-Code"

# Parse arguments
VALID_ARGS=()
MODEL_SET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)
            shift 2
            ;;
        -m|--model)
            MODEL_SET=true
            VALID_ARGS+=("--model" "$2")
            export CUSTOM_LLM_MODEL_NAME="$2"
            shift 2
            ;;
        *)
            VALID_ARGS+=("$1")
            shift
            ;;
    esac
done

if [ "$MODEL_SET" = false ]; then
    export CUSTOM_LLM_MODEL_NAME="$DEFAULT_MODEL"
    VALID_ARGS+=("--model" "$DEFAULT_MODEL")
fi

# Launch elc with valid arguments
elc "${VALID_ARGS[@]}"
