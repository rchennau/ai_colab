#!/usr/bin/env bash
# Atari-LX Technical Debate Wrapper
# Automates starting a technical debate between active agents with project context.

set -euo pipefail

usage() {
    echo "Usage: atari-debate <TOPIC> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --rounds N    Number of rebuttal rounds (default: 2)"
    echo "  --workers W   Comma-separated agent names (auto-detect if omitted)"
    exit 1
}

[[ $# -lt 1 ]] && usage

TOPIC="$1"; shift
ROUNDS=2
WORKERS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rounds) ROUNDS="$2"; shift 2 ;;
        --workers) WORKERS="$2"; shift 2 ;;
        *) usage ;;
    esac
done

# 1. Auto-detect workers if not provided
if [[ -z "$WORKERS" ]]; then
    echo "Auto-detecting active agents..."
    # Filter for known dev agents or workers, excluding the current script if it has an identity
    ACTIVE=$(hcom list --names | grep -E "dev|worker|qwen|gemini|claude|deepseek" | grep -v "judge" | head -n 3 | tr '\n' ',' | sed 's/,$//')
    WORKERS="$ACTIVE"
fi

if [[ -z "$WORKERS" ]]; then
    echo "Error: No active agents found for debate. Launch the dashboard first."
    exit 1
fi

echo "Topic: $TOPIC"
echo "Participants: $WORKERS"
echo "Rounds: $ROUNDS"

# 2. Gather Context from Blackboard
echo "Gathering project context..."
BLACKBOARD_CONTEXT=$(/home/rchennau/.hcom/scripts/hcom-kv list | head -n 20)
BUILD_STATE=$(hcom status | grep "dir:" || echo "Atari-LX project root")

FULL_CONTEXT="
Project State:
${BUILD_STATE}

Blackboard Data (Key Variables/Symbols):
${BLACKBOARD_CONTEXT}

Instructions for Debaters:
- Consider Atari 8-bit hardware constraints (6502 cycles, limited RAM).
- Reference the addresses/symbols from the blackboard if relevant.
- Prioritize performance for interrupt handlers and display routines.
- Prioritize maintainability for shell and filesystem logic.
"

# 3. Launch the debate
# Note: 'debate' is a built-in hcom script
exec hcom run debate "$TOPIC" --workers "$WORKERS" --rounds "$ROUNDS" --context "$FULL_CONTEXT"
