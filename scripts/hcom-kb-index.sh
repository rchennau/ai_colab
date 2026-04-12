#!/usr/bin/env bash
# hcom Semantic KB Indexer (RAG-lite)
# Generates a compact Project Map for LLM-based architectural search.

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

PROJECT_ROOT=$(detect_project_root)
MAP_FILE="$PROJECT_ROOT/conductor/knowledge_base_map.md"

log_info "Generating Project Map for Semantic KB..."

# 1. Build a list of all key project files
FILES=$(find "$PROJECT_ROOT" -maxdepth 3 -not -path '*/.*' | sed "s|$PROJECT_ROOT/||")

# 2. Get high-level directory structure
STRUCTURE=$(find "$PROJECT_ROOT" -maxdepth 2 -not -path '*/.*' -type d | sed "s|$PROJECT_ROOT/||")

# 3. Use Gemini to summarize the project
log_info "Consulting Gemini for project summarization..."

PROMPT="You are a senior software architect. Based on the following directory structure and file list, generate a compact 'Project Map' in Markdown format. For each major directory and core file, provide a 1-sentence description of its purpose within the project.

Project: ai-colab (Multi-agent orchestration environment)

Structure:
$STRUCTURE

Key Files:
$FILES

Format:
## Directory/File
- Description
"

if has_command gemini; then
    SUMMARY=$(gemini --model gemini-3.0 --headless --prompt "$PROMPT" 2>&1)
else
    SUMMARY="Error: Gemini CLI not found. Indexing failed."
    log_error "$SUMMARY"
    exit 1
fi

# 4. Save the map (Append summary to keep manual enhancements)
if grep -q "## Orchestration Core (Hub)" "$MAP_FILE"; then
    log_info "Manual project map detected. Appending automated summary..."
    cat << EOF >> "$MAP_FILE"

## Automated Discovery Update ($(date '+%Y-%m-%d %H:%M:%S'))
$SUMMARY
EOF
else
    cat << EOF > "$MAP_FILE"
# ai-colab Project Map (Semantic Knowledge Base)
Generated: $(date '+%Y-%m-%d %H:%M:%S')

$SUMMARY

## Index Metadata
- Status: Active
- Source: Automated Indexer (hcom-kb-index.sh)
EOF
fi

log_success "Project Map saved to: $MAP_FILE"
blackboard_set "kb_last_indexed" "$(date '+%Y-%m-%dT%H:%M:%S%z')"
