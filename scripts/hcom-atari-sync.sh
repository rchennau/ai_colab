#!/usr/bin/env bash
# hcom Atari-LX Build Sync
# Synchronizes build artifacts (symbols, segment addresses) to the Shared Blackboard

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Project paths
PROJECT_ROOT=$(detect_project_root)
MAP_FILE="$PROJECT_ROOT/build/bin/atari-lx.map"
KV_TOOL="$SCRIPT_DIR/hcom-kv"

echo "Synchronizing Atari-LX build state to Blackboard..."

if [[ ! -f "$MAP_FILE" ]]; then
    echo "Warning: Map file not found at $MAP_FILE. Run 'make build' first."
    exit 0
fi

# Parse segments from map file
# Example format: seg id=0,name="CODE",start=0x000800,size=0x4210,...
# We'll use grep and sed to extract start addresses

extract_seg_addr() {
    local seg_name="$1"
    # Find the line for the segment and extract the hex address
    # Format: ZEROPAGE              000080  0000AB  00002C  00001
    grep -E "^$seg_name\s+" "$MAP_FILE" | awk '{print "0x"$2}' || echo ""
}

# Sync standard segments
for seg in CODE RODATA BSS DATA ZEROPAGE CART_INIT; do
    ADDR=$(extract_seg_addr "$seg")
    if [[ -n "$ADDR" ]]; then
        "$KV_TOOL" set "atari_addr_$seg" "$ADDR"
        echo "  $seg -> $ADDR"
    fi
done

# Sync build timestamp
"$KV_TOOL" set atari_last_build "$(date '+%Y-%m-%dT%H:%M:%S%z')"

echo "Build sync complete."
