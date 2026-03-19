#!/usr/bin/env bash
# Claude CLI Wrapper with hcom Integration
# Launches Claude CLI with hcom registration

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Register with hcom to enable messaging
if has_command hcom; then
    AGENT_NAME="claude-$$"
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

# Default model (can be overridden)
DEFAULT_MODEL="claude-3-5-sonnet"

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
            # Keep all other arguments for claude
            VALID_ARGS+=("$1")
            shift
            ;;
    esac
done

# Add default model if not specified
if [ "$MODEL_SET" = false ]; then
    VALID_ARGS+=("-m" "$DEFAULT_MODEL")
fi

# Launch claude with valid arguments
exec claude "${VALID_ARGS[@]}"
