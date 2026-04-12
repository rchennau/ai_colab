#!/usr/bin/env bash
# ai-colab Cost Tracker (P5.3)
# Shell wrapper for the budget manager
# Usage: bash cost-tracker.sh <command> [options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUDGET_MANAGER="$SCRIPT_DIR/budget-manager.py"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1" >&2; }

# Show help
show_help() {
    echo ""
    echo -e "${BLUE}Usage:${NC}"
    echo "  bash cost-tracker.sh <command> [options]"
    echo ""
    echo -e "${BLUE}Commands:${NC}"
    echo "  record       Record token usage"
    echo "  status       Show usage and budget status"
    echo "  report       Generate usage report"
    echo "  set-budget   Set monthly budget for agent"
    echo "  alerts       Show budget alerts"
    echo "  ranking      Show cost efficiency ranking"
    echo "  help         Show this help message"
    echo ""
    echo -e "${BLUE}Options:${NC}"
    echo "  --agent <name>         Agent name"
    echo "  --input-tokens <n>     Input token count"
    echo "  --output-tokens <n>    Output token count"
    echo "  --budget <amount>      Monthly budget amount"
    echo "  --period <period>      Report period (daily/weekly/monthly)"
    echo "  --task-id <id>         Task ID for tracking"
}

# ============================================================
# Main
# ============================================================

main() {
    local command=""
    local agent=""
    local input_tokens=""
    local output_tokens=""
    local budget=""
    local period="daily"
    local task_id=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            record|status|report|set-budget|alerts|ranking|help)
                command="$1"
                shift
                ;;
            --agent)
                agent="$2"
                shift 2
                ;;
            --input-tokens)
                input_tokens="$2"
                shift 2
                ;;
            --output-tokens)
                output_tokens="$2"
                shift 2
                ;;
            --budget)
                budget="$2"
                shift 2
                ;;
            --period)
                period="$2"
                shift 2
                ;;
            --task-id)
                task_id="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Handle help command
    if [[ "$command" == "help" || -z "$command" ]]; then
        show_help
        exit 0
    fi

    # Build command
    local cmd=(python3 "$BUDGET_MANAGER" "$command")
    [[ -n "$agent" ]] && cmd+=(--agent "$agent")
    [[ -n "$input_tokens" ]] && cmd+=(--input-tokens "$input_tokens")
    [[ -n "$output_tokens" ]] && cmd+=(--output-tokens "$output_tokens")
    [[ -n "$budget" ]] && cmd+=(--budget "$budget")
    [[ -n "$period" ]] && cmd+=(--period "$period")
    [[ -n "$task_id" ]] && cmd+=(--task-id "$task_id")

    # Execute
    "${cmd[@]}"
}

main "$@"
