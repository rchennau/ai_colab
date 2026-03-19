#!/usr/bin/env bash
# NVIDIA NeMo CLI Wrapper with hcom Integration
# Launches NeMo (Nemotron) with hcom registration

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Register with hcom to enable messaging
if has_command hcom; then
    AGENT_NAME="${HCOM_NAME:-nemo-$$}"
    export HCOM_NAME="$AGENT_NAME"
    hcom start --as "$HCOM_NAME"
    hcom listen --name "$HCOM_NAME" --timeout 1
fi

# Default model
DEFAULT_MODEL="nvidia/llama-3.1-nemotron-70b-instruct"

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

# Launch nemo with valid arguments
exec nemo "${VALID_ARGS[@]}"
