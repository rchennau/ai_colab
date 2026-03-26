#!/usr/bin/env bash
# nemoclaw Architectural Review
# Requests a high-level review of a project component from the architect.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/utils.sh"

PATH_TO_REVIEW="${1:-.}"
PROJECT_ROOT=$(detect_project_root)

log_info "Initiating architectural review for: $PATH_TO_REVIEW"

CONTEXT=""
if [ -d "$PROJECT_ROOT/$PATH_TO_REVIEW" ]; then
    CONTEXT=$(find "$PROJECT_ROOT/$PATH_TO_REVIEW" -maxdepth 2 -not -path '*/.*' | head -n 20)
elif [ -f "$PROJECT_ROOT/$PATH_TO_REVIEW" ]; then
    CONTEXT=$(cat "$PROJECT_ROOT/$PATH_TO_REVIEW" | head -n 100)
fi

hcom send @nemoclaw --intent request --thread "architectural-review" -- \
    "Please perform an architectural review of the following component: $PATH_TO_REVIEW. 
    Context summary:
    $CONTEXT"

log_success "Review request sent to @nemoclaw."
