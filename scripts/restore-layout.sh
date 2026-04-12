#!/usr/bin/env bash
# Restore tmux Dashboard Layout (P17.5)
# Restores tmux session layout from previously saved JSON
# Usage: bash restore-layout.sh [session_name] [preset_name]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LAYOUT_DIR="$PROJECT_ROOT/.ai-colab/layouts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1" >&2; }

SESSION="${1:-hcom-dashboard}"
PRESET="${2:-default}"
LAYOUT_FILE="$LAYOUT_DIR/${PRESET}.json"

# Check if layout file exists
if [[ ! -f "$LAYOUT_FILE" ]]; then
    print_error "Layout file not found: $LAYOUT_FILE"
    print_info "Available layouts:"
    if [[ -d "$LAYOUT_DIR" ]]; then
        ls -1 "$LAYOUT_DIR"/*.json 2>/dev/null | while read -r f; do
            echo "  - $(basename "$f" .json)"
        done
    else
        echo "  (none)"
    fi
    exit 1
fi

# Check if session exists
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    print_error "Session '$SESSION' not found"
    exit 1
fi

print_info "Restoring layout '$PRESET' from: $LAYOUT_FILE"

# Restore layout using Python
python3 -c "
import json
import subprocess
import sys

layout_file = '$LAYOUT_FILE'
session = '$SESSION'

with open(layout_file) as f:
    layout = json.load(f)

print(f'Restoring {len(layout[\"windows\"])} windows, {len(layout[\"panes\"])} panes')

# Apply window layouts
for window in layout.get('windows', []):
    window_target = f'{session}:{window[\"index\"]}'
    layout_str = window.get('layout', '')

    # Select window
    subprocess.run(['tmux', 'select-window', '-t', window_target], capture_output=True)

    # Apply layout
    if layout_str:
        subprocess.run(['tmux', 'select-layout', '-t', window_target, layout_str], capture_output=True)

# Restore pane titles
for pane in layout.get('panes', []):
    pane_target = f'{session}:{pane[\"window_index\"]}.{pane[\"pane_index\"]}'
    title = pane.get('title', '')

    # Set pane title
    subprocess.run(['tmux', 'select-pane', '-t', pane_target, '-T', title], capture_output=True)

# Select first pane
subprocess.run(['tmux', 'select-pane', '-t', f'{session}:0.0'], capture_output=True)

print('Layout restored successfully')
" 2>&1

print_success "Layout '$PRESET' restored for session '$SESSION'"
