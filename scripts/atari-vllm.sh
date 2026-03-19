#!/usr/bin/env bash
# Atari-vLLM CLI Wrapper with hcom Integration
# Launches a remote vLLM agent specialized for Atari 800XL

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

if has_command hcom; then
    # Register with hcom to enable messaging
    AGENT_NAME="atari-vllm-$$"
    hcom start --as "$AGENT_NAME" > /dev/null 2>&1 || true
    export HCOM_NAME="$AGENT_NAME"

    # Ensure relay is running if more than one agent is active
    ACTIVE_AGENTS=$(hcom list --names | wc -w)
    if [ "$ACTIVE_AGENTS" -gt 1 ]; then
        hcom relay daemon start > /dev/null 2>&1 || true
    fi

    # Pulse session to transition from "launching" to "listening"
    hcom listen --name "$AGENT_NAME" --timeout 1 > /dev/null 2>&1 || true
fi

# Default model (vLLM expects the model name it was launched with)
DEFAULT_MODEL="deepseek-ai/DeepSeek-Coder-V2-Lite-Instruct"

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
            VALID_ARGS+=("$1" "$2")
            shift 2
            ;;
        *)
            VALID_ARGS+=("$1")
            shift
            ;;
    esac
done

if [ "$MODEL_SET" = false ]; then
    VALID_ARGS+=("-m" "$DEFAULT_MODEL")
fi

# Launch vllm-cli.py with valid arguments
# Prefer local version if it exists
if [[ -f "$SCRIPT_DIR/vllm-cli.py" ]]; then
    exec python3 "$SCRIPT_DIR/vllm-cli.py" "${VALID_ARGS[@]}"
else
    echo "Error: vllm-cli.py not found in $SCRIPT_DIR"
    exit 1
fi
