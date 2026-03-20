#!/usr/bin/env bash
# DeepSeek CLI Wrapper with hcom Integration
# Launches DeepSeek CLI with hcom registration

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Register with hcom to enable messaging
if has_command hcom; then
    # Use underscore instead of hyphen for hcom 0.7.5 compatibility
    AGENT_NAME="${HCOM_NAME:-deepseek_$$}"
    export HCOM_NAME="$AGENT_NAME"
    
    # Register and pulse
    hcom start --as "$HCOM_NAME" > /dev/null 2>&1 || true
    hcom listen --name "$HCOM_NAME" --timeout 1 > /dev/null 2>&1 || true
    
    # Start background heartbeat to prevent stale status
    (while true; do 
        hcom listen --name "$HCOM_NAME" --timeout 60 > /dev/null 2>&1 || sleep 60
    done) &
    HB_PID=$!
    trap "kill $HB_PID 2>/dev/null || true" EXIT
fi

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
deepseek "${VALID_ARGS[@]}"
