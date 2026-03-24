#!/usr/bin/env bash
# Atari Memory Map Generator
# Parses cc65 map files and generates a visual ASCII representation.

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/utils.sh"

PROJECT_ROOT=$(detect_project_root)
MAP_FILE="$PROJECT_ROOT/build/bin/atari-lx.map"
OUTPUT_FILE="$PROJECT_ROOT/conductor/reports/memory_map.txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

log_info "Parsing Atari map file: $MAP_FILE"

if [[ ! -f "$MAP_FILE" ]]; then
    log_error "Map file not found. Run 'make build' first."
    exit 1
fi

# Function to hex to dec
h2d() {
    echo $((16#$1))
}

# Function to dec to hex (4 digits)
d2h() {
    printf "%04X" "$1"
}

# 1. Parse Segments
# Format: Name                   Start   End     Size    Align
#         ----------------------------------------------------
#         ZEROPAGE               000080  0000AB  00002C  00001
# ...
log_info "Extracting segments..."

# Header for output
{
    echo "================================================================"
    echo "  Atari-LX Memory Map Visualization"
    echo "  Generated: $(date)"
    echo "================================================================"
    echo ""
    printf "%-15s %-10s %-10s %-10s %-5s\n" "Segment" "Start" "End" "Size" "Usage"
    echo "----------------------------------------------------------------"
} > "$OUTPUT_FILE"

# Parse the segments section
# We look for the start of the segments list
parsing=false
while read -r line; do
    if [[ "$line" == "Segment list"* ]]; then
        parsing=true
        read -r _ # skip header line 1
        read -r _ # skip header line 2
        continue
    fi
    
    [[ "$parsing" == false ]] && continue
    [[ -z "$line" ]] && break # End of segments
    
    # Extract columns
    name=$(echo "$line" | awk '{print $1}')
    start=$(echo "$line" | awk '{print $2}')
    end=$(echo "$line" | awk '{print $3}')
    size=$(echo "$line" | awk '{print $4}')
    
    # Calculate usage percentage (of 64KB for simplicity, or specific memory area)
    # Total space is $10000 (65536 bytes)
    size_dec=$(h2d "$size")
    usage_pct=$(echo "scale=2; ($size_dec * 100) / 65536" | bc)
    
    {
        printf "%-15s \$%-9s \$%-9s %-10d %-5s%%\n" "$name" "$start" "$end" "$size_dec" "$usage_pct"
    } >> "$OUTPUT_FILE"
done < "$MAP_FILE"

# 2. Generate ASCII Map
echo "" >> "$OUTPUT_FILE"
echo "--- 64KB Address Space Map ---" >> "$OUTPUT_FILE"
echo "[0000] [------------------------------------------------] [FFFF]" >> "$OUTPUT_FILE"

# In a full implementation, we'd draw a more detailed ASCII bar here.
# For now, let's just indicate the major regions.

log_success "Memory map report generated: $OUTPUT_FILE"
cat "$OUTPUT_FILE"
