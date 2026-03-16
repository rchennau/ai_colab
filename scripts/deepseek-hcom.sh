#!/usr/bin/env bash
# DeepSeek CLI Wrapper with hcom Integration
# Launches DeepSeek CLI with hcom registration

set -euo pipefail

# Register with hcom to enable messaging
AGENT_NAME="deepseek-$$"
hcom start --as "$AGENT_NAME" > /dev/null 2>&1 || true
export HCOM_NAME="$AGENT_NAME"

# Ensure relay is running if more than one agent is active
ACTIVE_AGENTS=$(hcom list --names | wc -w)
if [ "$ACTIVE_AGENTS" -gt 1 ]; then
    hcom relay daemon start > /dev/null 2>&1 || true
fi

# Pulse session to transition from "launching" to "listening"
hcom listen --name "$AGENT_NAME" --timeout 1 > /dev/null 2>&1 || true

# Default model (can be overridden)
DEFAULT_MODEL="deepseek-v3"

# Parse arguments
VALID_ARGS=()
MODEL_SET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)
            # Skip --name and value
            shift 2
            ;;
        -m|--model)
            # Model specified, don't add default
            MODEL_SET=true
            VALID_ARGS+=("$1" "$2")
            shift 2
            ;;
        *)
            # Keep all other arguments for deepseek
            VALID_ARGS+=("$1")
            shift
            ;;
    esac
done

# Add default model if not specified
if [ "$MODEL_SET" = false ]; then
    VALID_ARGS+=("-m" "$DEFAULT_MODEL")
fi

# Launch deepseek with valid arguments
exec deepseek "${VALID_ARGS[@]}"
