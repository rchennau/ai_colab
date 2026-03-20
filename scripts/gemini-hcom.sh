#!/usr/bin/env bash
# Gemini Agent Wrapper (Consolidated)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/agent-wrapper.sh" gemini "$@"
