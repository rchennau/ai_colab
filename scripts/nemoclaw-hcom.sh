#!/usr/bin/env bash
# nemoclaw Agent Wrapper
# Connects the nemoclaw architect to the hcom hub via NVIDIA NIM API.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Ensure NVIDIA_API_KEY is available (might be in .zshrc_secrets or local .ai-colab-env)
if [ -f "$HOME/.ai-colab-env" ]; then
    source "$HOME/.ai-colab-env"
fi

# Fallback to .zshrc_secrets if possible
if [[ -z "${NVIDIA_API_KEY:-}" ]] && [ -f "$HOME/.zshrc_secrets" ]; then
    export NVIDIA_API_KEY=$(grep "NVIDIA_API_KEY" "$HOME/.zshrc_secrets" | cut -d'"' -f2 || echo "")
fi

# Launch using the generic agent wrapper
exec bash "$SCRIPT_DIR/agent-wrapper.sh" nemoclaw "$@"
