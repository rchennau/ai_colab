#!/usr/bin/env bash
# ai-colab Agent Memory Helper (P5.2)
# Shell wrapper for the memory manager
# Usage: bash agent-memory.sh <command> [options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MEMORY_MANAGER="$SCRIPT_DIR/memory-manager.py"
MEMORY_CONFIG="$PROJECT_ROOT/config/memory-config.json"

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
    echo "  bash agent-memory.sh <command> [options]"
    echo ""
    echo -e "${BLUE}Commands:${NC}"
    echo "  save    Save a conversation message"
    echo "  load    Load conversation context"
    echo "  compress Compress old messages"
    echo "  status  Show memory status"
    echo "  clear   Clear all memory for agent"
    echo "  export  Export memory to file"
    echo "  help    Show this help message"
    echo ""
    echo -e "${BLUE}Options:${NC}"
    echo "  --agent <name>       Agent name (required)"
    echo "  --role <role>        Message role (user/assistant/system)"
    echo "  --message <text>     Message content"
    echo "  --max-messages <n>   Max messages to load"
    echo "  --max-bytes <n>      Max bytes to load"
    echo "  --file <path>        File to save/load"
    echo "  --config <path>      Config file path"
}

# Save a message
save_message() {
    local agent="$1"
    local role="${2:-user}"
    local message="$3"

    if [[ -z "$agent" || -z "$message" ]]; then
        print_error "Agent and message required for save"
        return 1
    fi

    python3 "$MEMORY_MANAGER" save \
        --agent "$agent" \
        --role "$role" \
        --message "$message" \
        ${MEMORY_CONFIG:+--config "$MEMORY_CONFIG"}

    print_success "Message saved for $agent ($role)"
}

# Load conversation context
load_context() {
    local agent="$1"
    local max_messages="${2:-}"
    local max_bytes="${3:-}"
    local output_file="${4:-}"

    if [[ -z "$agent" ]]; then
        print_error "Agent required for load"
        return 1
    fi

    local cmd=(python3 "$MEMORY_MANAGER" load --agent "$agent")
    [[ -n "$max_messages" ]] && cmd+=(--max-messages "$max_messages")
    [[ -n "$max_bytes" ]] && cmd+=(--max-bytes "$max_bytes")
    [[ -n "$output_file" ]] && cmd+=(--file "$output_file")
    ${MEMORY_CONFIG:+cmd+=(--config "$MEMORY_CONFIG")}

    "${cmd[@]}"
}

# Show memory status
show_status() {
    local agent="$1"

    if [[ -z "$agent" ]]; then
        print_error "Agent required for status"
        return 1
    fi

    python3 "$MEMORY_MANAGER" status \
        --agent "$agent" \
        ${MEMORY_CONFIG:+--config "$MEMORY_CONFIG"}
}

# ============================================================
# Main
# ============================================================

main() {
    local command=""
    local agent=""
    local role="user"
    local message=""
    local max_messages=""
    local max_bytes=""
    local output_file=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            save|load|compress|status|clear|export|help)
                command="$1"
                shift
                ;;
            --agent)
                agent="$2"
                shift 2
                ;;
            --role)
                role="$2"
                shift 2
                ;;
            --message)
                message="$2"
                shift 2
                ;;
            --max-messages)
                max_messages="$2"
                shift 2
                ;;
            --max-bytes)
                max_bytes="$2"
                shift 2
                ;;
            --file)
                output_file="$2"
                shift 2
                ;;
            --config)
                MEMORY_CONFIG="$2"
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

    # Validate command
    if [[ -z "$command" ]]; then
        print_error "Command required"
        show_help
        exit 1
    fi

    # Execute command
    case "$command" in
        save)
            save_message "$agent" "$role" "$message"
            ;;
        load)
            load_context "$agent" "$max_messages" "$max_bytes" "$output_file"
            ;;
        compress)
            python3 "$MEMORY_MANAGER" compress --agent "$agent" ${MEMORY_CONFIG:+--config "$MEMORY_CONFIG"}
            ;;
        status)
            show_status "$agent"
            ;;
        clear)
            python3 "$MEMORY_MANAGER" clear --agent "$agent" ${MEMORY_CONFIG:+--config "$MEMORY_CONFIG"}
            print_success "Memory cleared for $agent"
            ;;
        export)
            python3 "$MEMORY_MANAGER" export --agent "$agent" ${output_file:+--file "$output_file"} ${MEMORY_CONFIG:+--config "$MEMORY_CONFIG"}
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
