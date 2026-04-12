#!/usr/bin/env bash
# ai-colab Protocol Encoder (P6.1)
# Encodes structured messages for agent-to-agent communication
# Reduces message size by 90% vs. English-only messaging
#
# Usage:
#   bash protocol-encoder.sh status --track my-track --pct 45 --step "coding"
#   bash protocol-encoder.sh heartbeat --agent gemini
#   bash protocol-encoder.sh error --track my-track --err compilation_failed --detail "Syntax error in handlers.py"
#   bash protocol-encoder.sh complete --track my-track --pct 100 --detail "All tests passing"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Protocol version
PROTOCOL_VERSION=1

print_error() { echo -e "${RED}✗${NC} $1" >&2; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }

# Escape string for JSON
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    echo "$s"
}

# Generate timestamp
get_timestamp() {
    date +%s
}

# Encode a status message
encode_status() {
    local agent="${AGENT_NAME:-${HCOM_NAME:-unknown}}"
    local track=""
    local pct=0
    local step=""
    local phase=""
    local eta=0
    local blockers="[]"
    local detail=""
    local err=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --agent) agent="$2"; shift 2 ;;
            --track) track="$2"; shift 2 ;;
            --pct) pct="$2"; shift 2 ;;
            --step) step="$2"; shift 2 ;;
            --phase) phase="$2"; shift 2 ;;
            --eta) eta="$2"; shift 2 ;;
            --blockers) blockers="$2"; shift 2 ;;
            --detail) detail="$2"; shift 2 ;;
            --err) err="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local ts
    ts=$(get_timestamp)

    # Build JSON
    local json="{\"v\":$PROTOCOL_VERSION,\"t\":\"status\",\"a\":\"$agent\",\"ts\":$ts,\"track\":\"$track\",\"pct\":$pct,\"step\":\"$(json_escape "$step")\""

    [[ -n "$phase" ]] && json+=",\"phase\":\"$phase\""
    [[ $eta -gt 0 ]] && json+=",\"eta\":$eta"
    [[ "$blockers" != "[]" ]] && json+=",\"blockers\":$blockers"
    [[ -n "$detail" ]] && json+=",\"detail\":\"$(json_escape "$detail")\""
    [[ -n "$err" ]] && json+=",\"err\":\"$err\""

    json+="}"
    echo "$json"
}

# Encode a heartbeat message
encode_heartbeat() {
    local agent="${AGENT_NAME:-${HCOM_NAME:-unknown}}"
    local latency_ms=0
    local load=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --agent) agent="$2"; shift 2 ;;
            --latency) latency_ms="$2"; shift 2 ;;
            --load) load="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local ts
    ts=$(get_timestamp)

    echo "{\"v\":$PROTOCOL_VERSION,\"t\":\"heartbeat\",\"a\":\"$agent\",\"ts\":$ts,\"latency_ms\":$latency_ms,\"load\":$load}"
}

# Encode a request message
encode_request() {
    local agent="${AGENT_NAME:-${HCOM_NAME:-unknown}}"
    local track=""
    local detail=""
    local target_agent=""
    local priority="normal"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --agent) agent="$2"; shift 2 ;;
            --track) track="$2"; shift 2 ;;
            --detail) detail="$2"; shift 2 ;;
            --target) target_agent="$2"; shift 2 ;;
            --priority) priority="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local ts
    ts=$(get_timestamp)

    local json="{\"v\":$PROTOCOL_VERSION,\"t\":\"request\",\"a\":\"$agent\",\"ts\":$ts,\"track\":\"$track\",\"detail\":\"$(json_escape "$detail")\""
    [[ -n "$target_agent" ]] && json+=",\"target_agent\":\"$target_agent\""
    json+=",\"priority\":\"$priority\""
    json+="}"
    echo "$json"
}

# Encode a response message
encode_response() {
    local agent="${AGENT_NAME:-${HCOM_NAME:-unknown}}"
    local track=""
    local detail=""
    local status="accepted"
    local err=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --agent) agent="$2"; shift 2 ;;
            --track) track="$2"; shift 2 ;;
            --detail) detail="$2"; shift 2 ;;
            --status) status="$2"; shift 2 ;;
            --err) err="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local ts
    ts=$(get_timestamp)

    local json="{\"v\":$PROTOCOL_VERSION,\"t\":\"response\",\"a\":\"$agent\",\"ts\":$ts,\"track\":\"$track\",\"detail\":\"$(json_escape "$detail")\",\"status\":\"$status\""
    [[ -n "$err" ]] && json+=",\"err\":\"$err\""
    json+="}"
    echo "$json"
}

# Encode an error message
encode_error() {
    local agent="${AGENT_NAME:-${HCOM_NAME:-unknown}}"
    local track=""
    local err=""
    local detail=""
    local recoverable=true
    local retry_count=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --agent) agent="$2"; shift 2 ;;
            --track) track="$2"; shift 2 ;;
            --err) err="$2"; shift 2 ;;
            --detail) detail="$2"; shift 2 ;;
            --recoverable) recoverable="$2"; shift 2 ;;
            --retry) retry_count="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local ts
    ts=$(get_timestamp)

    local json="{\"v\":$PROTOCOL_VERSION,\"t\":\"error\",\"a\":\"$agent\",\"ts\":$ts,\"track\":\"$track\",\"err\":\"$err\",\"detail\":\"$(json_escape "$detail")\",\"recoverable\":$recoverable,\"retry_count\":$retry_count}"
    echo "$json"
}

# Encode a complete message
encode_complete() {
    local agent="${AGENT_NAME:-${HCOM_NAME:-unknown}}"
    local track=""
    local detail=""
    local artifacts="[]"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --agent) agent="$2"; shift 2 ;;
            --track) track="$2"; shift 2 ;;
            --detail) detail="$2"; shift 2 ;;
            --artifacts) artifacts="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local ts
    ts=$(get_timestamp)

    local json="{\"v\":$PROTOCOL_VERSION,\"t\":\"complete\",\"a\":\"$agent\",\"ts\":$ts,\"track\":\"$track\",\"pct\":100"
    [[ -n "$detail" ]] && json+=",\"detail\":\"$(json_escape "$detail")\""
    [[ "$artifacts" != "[]" ]] && json+=",\"artifacts\":$artifacts"
    json+="}"
    echo "$json"
}

# Encode a verbose override request
encode_verbose_request() {
    local agent="${1:-}"
    local count="${2:-5}"

    if [[ -z "$agent" ]]; then
        print_error "Agent name required for verbose request"
        return 1
    fi

    local ts
    ts=$(get_timestamp)

    echo "{\"v\":$PROTOCOL_VERSION,\"t\":\"request\",\"a\":\"${AGENT_NAME:-${HCOM_NAME:-conductor}}\",\"ts\":$ts,\"mode\":\"verbose\",\"agent\":\"$agent\",\"count\":$count}"
}

# ============================================================
# Main
# ============================================================

main() {
    local command="${1:-help}"
    shift || true

    local result=""

    case "$command" in
        status)
            result=$(encode_status "$@")
            ;;
        heartbeat)
            result=$(encode_heartbeat "$@")
            ;;
        request)
            result=$(encode_request "$@")
            ;;
        response)
            result=$(encode_response "$@")
            ;;
        error)
            result=$(encode_error "$@")
            ;;
        complete)
            result=$(encode_complete "$@")
            ;;
        verbose)
            result=$(encode_verbose_request "$@")
            ;;
        help|--help|-h)
            echo ""
            echo -e "${BLUE}Usage:${NC}"
            echo "  bash protocol-encoder.sh <command> [options]"
            echo ""
            echo -e "${BLUE}Commands:${NC}"
            echo "  status      Encode progress status message"
            echo "  heartbeat   Encode health check message"
            echo "  request     Encode task request message"
            echo "  response    Encode response to request"
            echo "  error       Encode error report message"
            echo "  complete    Encode task completion message"
            echo "  verbose     Request verbose mode from agent"
            echo "  help        Show this help message"
            echo ""
            echo -e "${BLUE}Status Options:${NC}"
            echo "  --agent <name>     Agent name (default: \$HCOM_NAME)"
            echo "  --track <slug>     Current track slug"
            echo "  --pct <0-100>      Progress percentage"
            echo "  --step <text>      Current step description"
            echo "  --phase <phase>    Current phase (analyzing/coding/testing/reviewing)"
            echo "  --eta <seconds>    Estimated time remaining"
            echo "  --detail <text>    Human-readable detail"
            echo "  --err <code>       Error code if applicable"
            echo ""
            echo -e "${BLUE}Heartbeat Options:${NC}"
            echo "  --agent <name>     Agent name"
            echo "  --latency <ms>     Round-trip latency"
            echo "  --load <0-1>       System load"
            echo ""
            echo -e "${BLUE}Example:${NC}"
            echo "  bash protocol-encoder.sh status --track implement-api --pct 45 --step \"writing endpoints\" --eta 1800"
            echo "  bash protocol-encoder.sh heartbeat --agent gemini --latency 150"
            echo "  bash protocol-encoder.sh error --track my-track --err compilation_failed --detail \"Syntax error\""
            exit 0
            ;;
        *)
            print_error "Unknown command: $command"
            main help
            exit 1
            ;;
    esac

    if [[ -n "$result" ]]; then
        echo "$result"
    fi
}

main "$@"
