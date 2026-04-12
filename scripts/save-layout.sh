#!/usr/bin/env bash
# Save tmux Dashboard Layout (P17.5)
# Saves current tmux session layout to JSON for later restoration
# Usage: bash save-layout.sh [session_name] [preset_name]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LAYOUT_DIR="$PROJECT_ROOT/.ai-colab/layouts"
mkdir -p "$LAYOUT_DIR"

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

# Check if session exists
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    print_error "Session '$SESSION' not found"
    exit 1
fi

# Generate JSON layout using tmux commands
python3 -c "
import json
import subprocess
import time

session = '$SESSION'
layout_file = '$LAYOUT_FILE'

layout = {
    'preset': '$PRESET',
    'session': session,
    'timestamp': subprocess.run(['date', '+%Y-%m-%dT%H:%M:%S'], capture_output=True, text=True).stdout.strip(),
    'windows': [],
    'panes': []
}

# Get window info
windows = subprocess.run(
    ['tmux', 'list-windows', '-t', session, '-F', '#{window_index} #{window_name} #{window_layout}'],
    capture_output=True, text=True
).stdout.strip().split('\n')

for w in windows:
    if w.strip():
        parts = w.split(' ', 2)
        if len(parts) >= 3:
            layout['windows'].append({
                'index': parts[0],
                'name': parts[1],
                'layout': parts[2]
            })

# Get pane info
panes = subprocess.run(
    ['tmux', 'list-panes', '-t', session, '-F', '#{window_index} #{pane_index} #{pane_title} #{pane_current_command}'],
    capture_output=True, text=True
).stdout.strip().split('\n')

for p in panes:
    if p.strip():
        parts = p.split(' ', 3)
        if len(parts) >= 4:
            layout['panes'].append({
                'window_index': parts[0],
                'pane_index': parts[1],
                'title': parts[2],
                'command': parts[3]
            })

# Save to file
with open(layout_file, 'w') as f:
    json.dump(layout, f, indent=2)

print(f'Saved layout to {layout_file}')
print(f'Windows: {len(layout[\"windows\"])}, Panes: {len(layout[\"panes\"])}')
" 2>&1

print_success "Layout '$PRESET' saved for session '$SESSION'"
