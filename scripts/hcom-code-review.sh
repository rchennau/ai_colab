#!/usr/bin/env bash
# hcom Automated Code Review
# Reviews changed files against project style guides using an LLM.

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

FILE_PATH="$1"
[[ -z "$FILE_PATH" ]] && { echo "Usage: hcom-code-review.sh <file_path>"; exit 1; }
[[ ! -f "$FILE_PATH" ]] && { echo "Error: File not found: $FILE_PATH"; exit 1; }

STYLE_GUIDE="conductor/code_styleguides/general.md"
[[ ! -f "$STYLE_GUIDE" ]] && STYLE_GUIDE=""

echo "Running code review for: $FILE_PATH..."

# Prepare prompt
PROMPT="Review the following file against the project style guide (if provided). Identify any violations or areas for improvement in terms of readability, consistency, and simplicity. Provide a concise summary of findings.
File: $FILE_PATH
Content:
$(cat "$FILE_PATH")

$( [[ -n "$STYLE_GUIDE" ]] && echo "Style Guide:
$(cat "$STYLE_GUIDE")" )"

# Run review via Gemini
if has_command gemini; then
    REVIEW=$(gemini --model gemini-3.0 --headless --prompt "$PROMPT" 2>&1)
else
    REVIEW="Gemini CLI not found. Manual review required."
fi

# Determine if review is "Green" (pass) or "Red" (fail)
# Simple logic: if 'REJECTED' or 'VIOLATION' appears in the first 10 lines, it's a fail.
STATUS="PASS"
if echo "$REVIEW" | head -n 10 | grep -Ei "REJECTED|VIOLATION|CRITICAL" > /dev/null; then
    STATUS="FAIL"
fi

# Update Blackboard
BLACKBOARD_KEY="review_$(echo "$FILE_PATH" | tr '/' '_')"
blackboard_set "$BLACKBOARD_KEY" "$STATUS"

# Broadcast review summary
hcom send @all --intent inform --thread "plan-sync" -- \
    "Code Review [$STATUS]: $FILE_PATH. Summary: $(echo "$REVIEW" | head -n 3)..."

echo "$REVIEW"
[[ "$STATUS" == "PASS" ]] || exit 1
