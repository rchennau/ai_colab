#!/usr/bin/env bash
# hcom Atari-LX Visual Debugging
# Captures emulator screenshot and broadcasts analysis to the team.

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/utils.sh"

# Project paths
PROJECT_ROOT=$(detect_project_root)
SCREENSHOT_DIR="$PROJECT_ROOT/output/screenshots"
KV_TOOL="$SCRIPT_DIR/hcom-kv"
HCOM_NAME="${HCOM_NAME:-screen-bot}"

print_info() { echo -e "\033[0;34mℹ\033[0m $1"; }

mkdir -p "$SCREENSHOT_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
# IMG_PATH="$SCREENSHOT_DIR/screen-$TIMESTAMP.png" # Not used directly if we use find

echo "Capturing Atari screen state..."

# 1. Capture screenshot
# We'll try to find a running atari800 process and use its screenshot feature
if has_command atari800; then
    print_info "Attempting to trigger atari800 screenshot..."
    # atari800 doesn't have a direct "take screenshot now" CLI command while running
fi

# Fallback: check if any recent PNG was created in common locations
RECENT_FILE=$(find "$SCREENSHOT_DIR" -name "*.png" -mmin -1 2>/dev/null | head -n 1)

if [[ -z "$RECENT_FILE" ]]; then
    echo "Warning: No recent screenshot found in $SCREENSHOT_DIR."
    echo "Please take a screenshot in Altirra/Atari800 first."
    exit 0
fi

IMG_PATH="$RECENT_FILE"
echo "Found recent screenshot: $IMG_PATH"

# 2. Analyze screen via atari-dev-agent (MCP)
# We use 'gemini' to call the tool since it has the capability
echo "Analyzing visual state..."
if has_command gemini; then
    ANALYSIS=$(gemini --model gemini-3.0 --headless --prompt "Analyze this Atari screenshot: $IMG_PATH. Describe the current screen layout, any visible errors, and the state of the shell or game." 2>&1)
else
    ANALYSIS="Gemini CLI not found. Visual analysis unavailable."
fi

# 3. Store in Blackboard
"$KV_TOOL" set atari_last_screenshot "$IMG_PATH"
"$KV_TOOL" set atari_visual_state "$(echo "$ANALYSIS" | head -n 1 | cut -c1-100)..."

# 4. Broadcast to team
if has_command hcom; then
    hcom send @all --intent inform --thread "visual-debug" -- \
        "Visual State Update: $ANALYSIS [File: $IMG_PATH]"
fi

echo "Visual sync complete."
