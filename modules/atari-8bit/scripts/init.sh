#!/usr/bin/env bash
# Atari-8bit Module Initialization
# This script is called by the dashboard launcher during startup.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Initialize hardware constants in Blackboard
if [[ -f "$SCRIPT_DIR/init-atari-constants.sh" ]]; then
    bash "$SCRIPT_DIR/init-atari-constants.sh"
fi

# Synchronize build state
if [[ -f "$SCRIPT_DIR/hcom-atari-sync.sh" ]]; then
    bash "$SCRIPT_DIR/hcom-atari-sync.sh"
fi
