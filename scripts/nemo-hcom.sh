#!/usr/bin/env bash
# Nemo Agent Wrapper (Consolidated)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/agent-wrapper.sh" nemo "$@"
