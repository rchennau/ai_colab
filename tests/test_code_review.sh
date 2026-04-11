#!/usr/bin/env bash
# Test hcom-code-review.sh
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Mock/Override DB_PATH for testing
export HCOM_DB_PATH="/tmp/test_hcom_review.db"
rm -f "$HCOM_DB_PATH"

# Mock gemini command
gemini() {
    if [[ "$*" == *"fail"* ]]; then
        echo "VIOLATION: Code quality is low."
    else
        echo "Code review: All good."
    fi
}
export -f gemini

# Mock hcom command
hcom() {
    echo "Mock hcom: $*"
}
export -f hcom

# Create a dummy file to review
DUMMY_FILE="/tmp/test_review_file.txt"
echo "Test code" > "$DUMMY_FILE"

# 1. Test Passing Review
echo "Testing passing review..."
bash "$SCRIPT_DIR/hcom-code-review.sh" "$DUMMY_FILE" > /dev/null

STATUS=$(blackboard_get "review_$(echo "$DUMMY_FILE" | tr '/' '_')")
if [[ "$STATUS" == "PASS" ]]; then
    echo "SUCCESS: Review passed correctly."
else
    echo "FAILURE: Status is '$STATUS', expected 'PASS'."
    exit 1
fi

# 2. Test Failing Review
echo "Testing failing review..."
echo "This should fail" > "$DUMMY_FILE"
# We need to ensure the "fail" keyword is in the prompt for our mock
# hcom-code-review.sh reads the file content and puts it in the prompt
bash "$SCRIPT_DIR/hcom-code-review.sh" "$DUMMY_FILE" > /dev/null || true

STATUS=$(blackboard_get "review_$(echo "$DUMMY_FILE" | tr '/' '_')")
if [[ "$STATUS" == "FAIL" ]]; then
    echo "SUCCESS: Review failed correctly."
else
    echo "FAILURE: Status is '$STATUS', expected 'FAIL'."
    exit 1
fi

echo "All code-review tests passed!"
rm -f "$HCOM_DB_PATH" "$DUMMY_FILE"
