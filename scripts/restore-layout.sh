#!/usr/bin/env bash
# Restore tmux Dashboard Layout (P17.5)
# Restores tmux session layout from previously saved JSON
# Usage: bash restore-layout.sh [session_name] [preset_name]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Layout storage directory
LAYOUT_DIR="$PROJECT_ROOT/.ai-colab/layouts"

# Default session and preset names
SESSION="${1:-hcom-dashboard}"
PRESET="${2:-default}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1" >&2; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

# Layout file
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

print_info "Restoring layout '$PRESET' from: $LAYOUT_FILE"

# Restore layout using Python
python3 -c "
import json
import subprocess
import sys
import time

layout_file = '$LAYOUT_FILE'
session = '$SESSION'

# Load layout
with open(layout_file) as f:
    layout = json.load(f)

print(f'Restoring {len(layout[\"windows\"])} windows, {len(layout[\"panes\"])} panes')

# Check if session exists
result = subprocess.run(['tmux', 'has-session', '-t', session], capture_output=True)
if result.returncode != 0:
    print(f'Error: Session {session} not found')
    sys.exit(1)

# Apply window layouts
for window in layout['windows']:
    window_target = f'{session}:{window[\"index\"]}'
    layout_str = window['layout']

    # Select window
    subprocess.run(['tmux', 'select-window', '-t', window_target], capture_output=True)

    # Apply layout
    subprocess.run(['tmux', 'select-layout', '-t', window_target, layout_str], capture_output=True)
    time.sleep(0.1)

# Restore pane titles
for pane in layout['panes']:
    pane_target = f'{session}:{pane[\"window_index\"]}.{pane[\"pane_index\"]}'
    title = pane['title']

    # Set pane title
    subprocess.run(['tmux', 'select-pane', '-t', pane_target, '-T', title], capture_output=True)
    time.sleep(0.05)

# Select first pane
subprocess.run(['tmux', 'select-pane', '-t', f'{session}:0.0'], capture_output=True)

print('Layout restored successfully')
"

print_success "Layout '$PRESET' restored successfully"
