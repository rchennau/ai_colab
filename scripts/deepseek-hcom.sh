#!/usr/bin/env bash
# DeepSeek CLI Wrapper with hcom Integration
# Launches DeepSeek CLI with hcom registration

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Register with hcom to enable messaging
if has_command hcom; then
    AGENT_NAME="${HCOM_NAME:-deepseek-$$}"
    export HCOM_NAME="$AGENT_NAME"
    hcom start --as "$HCOM_NAME"
    hcom listen --name "$HCOM_NAME" --timeout 1
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
exec deepseek "${VALID_ARGS[@]}"
