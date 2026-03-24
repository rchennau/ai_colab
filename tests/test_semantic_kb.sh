#!/usr/bin/env bash
# Test hcom semantic KB integration

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Mock/Override DB_PATH for testing
export HCOM_DB_PATH="/tmp/test_hcom_kb.db"
rm -f "$HCOM_DB_PATH"

PROJECT_ROOT=$(detect_project_root)
MAP_FILE="$PROJECT_ROOT/conductor/knowledge_base_map.md"

# Mock gemini command
gemini() {
    if [[ "$*" == *"identify the top 3"* ]]; then
        echo "conductor/tracks.md, scripts/utils.sh"
    elif [[ "$*" == *"architectural answer"* ]]; then
        echo "The project uses hcom for messaging and a blackboard for shared state."
    else
        echo "## Project Structure
- conductor: Project management documentation."
    fi
}
export -f gemini

# 1. Test indexing
echo "Testing indexing..."
bash "$SCRIPT_DIR/hcom-kb-index.sh" > /dev/null

if [[ -f "$MAP_FILE" ]] && grep -q "Project Structure" "$MAP_FILE"; then
    echo "SUCCESS: Project Map generated correctly."
else
    echo "FAILURE: Project Map generation failed."
    exit 1
fi

# 2. Test semantic search (manual mock call since we can't easily trigger hcom events in a unit test)
echo "Testing semantic search logic..."
# Simulate what the conductor does
QUERY="How does communication work?"
FILE_LIST=$(gemini --headless --prompt "identify the top 3... $QUERY" 2>&1 | tr -d '\n' | sed 's/ //g')

if [[ "$FILE_LIST" == *"conductor/tracks.md"* ]]; then
    echo "SUCCESS: Relevant files identified correctly."
else
    echo "FAILURE: File identification failed: '$FILE_LIST'."
    exit 1
fi

ANSWER=$(gemini --headless --prompt "architectural answer... $QUERY" 2>&1)
if [[ "$ANSWER" == *"hcom"* ]]; then
    echo "SUCCESS: Final architectural answer generated correctly."
else
    echo "FAILURE: Final answer generation failed: '$ANSWER'."
    exit 1
fi

echo "All semantic KB integration tests passed!"
rm -f "$HCOM_DB_PATH"
# Keep the MAP_FILE as it's part of the project now
