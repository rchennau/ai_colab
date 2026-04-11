#!/usr/bin/env bash
# Save tmux Dashboard Layout (P17.5)
# Saves current tmux session layout to JSON for later restoration
# Usage: bash save-layout.sh [session_name] [preset_name]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Layout storage directory
LAYOUT_DIR="$PROJECT_ROOT/.ai-colab/layouts"
mkdir -p "$LAYOUT_DIR"

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

# Check if session exists
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    print_error "Session '$SESSION' not found"
    exit 1
fi

# Get session info
PANE_COUNT=$(tmux list-panes -t "$SESSION" | wc -l)
WINDOW_COUNT=$(tmux list-windows -t "$SESSION" | wc -l)

print_info "Saving layout for session: $SESSION"
print_info "Panes: $PANE_COUNT, Windows: $WINDOW_COUNT"

# Generate JSON layout using tmux commands
LAYOUT_FILE="$LAYOUT_DIR/${PRESET}.json"

python3 -c "
import json
import subprocess
import os

session = '$SESSION'
preset = '$PRESET'

layout = {
    'preset': preset,
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
layout_file = '$LAYOUT_FILE'
os.makedirs(os.path.dirname(layout_file), exist_ok=True)
with open(layout_file, 'w') as f:
    json.dump(layout, f, indent=2)

print(f'Layout saved to: {layout_file}')
print(f'Windows: {len(layout[\"windows\"])}, Panes: {len(layout[\"panes\"])}')
"

print_success "Layout '$PRESET' saved successfully"
